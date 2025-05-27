-- Veritabanı Oluşturma
CREATE DATABASE IF NOT EXISTS supermarket3
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE supermarket3;

-- Tablolar

CREATE TABLE Staff (
  StaffID     INT AUTO_INCREMENT PRIMARY KEY,
  Name        VARCHAR(50) NOT NULL,
  Surname     VARCHAR(50) NOT NULL,
  BirthDate   DATE        NOT NULL,
  SuperID     INT         NULL,
  Salary      DECIMAL(12,2) NOT NULL CHECK (Salary >= 0),
  Gender      ENUM('M','F','Other') NOT NULL,
  FOREIGN KEY (SuperID) REFERENCES Staff(StaffID)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE Branch (
  BranchNo    INT AUTO_INCREMENT PRIMARY KEY,
  BranchName  VARCHAR(100) NOT NULL,
  Location    VARCHAR(100) NOT NULL,
  MgrID       INT NOT NULL,
  FOREIGN KEY (MgrID) REFERENCES Staff(StaffID)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE ProductType (
  TypeID        INT AUTO_INCREMENT PRIMARY KEY,
  TypeName      VARCHAR(50) NOT NULL,
  ReorderLevel  INT         NOT NULL CHECK (ReorderLevel >= 0),
  TaxRate       DECIMAL(5,2) NOT NULL CHECK (TaxRate >= 0)
) ENGINE=InnoDB;

CREATE TABLE Product (
  ProductID      INT AUTO_INCREMENT PRIMARY KEY,
  ProductName    VARCHAR(100) NOT NULL,
  ProductTypeID  INT NOT NULL,
  BarcodeNumber  VARCHAR(50) UNIQUE NOT NULL,
  Price          DECIMAL(10,2) NOT NULL CHECK (Price >= 0),
  FOREIGN KEY (ProductTypeID) REFERENCES ProductType(TypeID)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Stock (
  BranchNo   INT NOT NULL,
  ProductID  INT NOT NULL,
  Amount     INT NOT NULL CHECK (Amount >= 0),
  PRIMARY KEY (BranchNo, ProductID),
  FOREIGN KEY (BranchNo) REFERENCES Branch(BranchNo)
    ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Customer (
  CustomerID       INT AUTO_INCREMENT PRIMARY KEY,
  RegisterDate     DATE NOT NULL,
  CustomerDiscount DECIMAL(5,2) NOT NULL CHECK (CustomerDiscount BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE TABLE SaleHeader (
  SaleID       INT AUTO_INCREMENT PRIMARY KEY,
  BranchNo     INT NOT NULL,
  CustomerID   INT NOT NULL,
  StaffID      INT NOT NULL,
  SaleDate     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  TotalAmount  DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (TotalAmount >= 0),
  FOREIGN KEY (BranchNo) REFERENCES Branch(BranchNo)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (StaffID) REFERENCES Staff(StaffID)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE SaleLine(
  SaleID        INT NOT NULL,
  ProductID     INT NOT NULL,
  QuantitySold  INT NOT NULL CHECK (QuantitySold > 0),
  UnitPrice     DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
  PRIMARY KEY (SaleID, ProductID),
  FOREIGN KEY (SaleID) REFERENCES SaleHeader(SaleID)
    ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE Works (
  StaffID    INT NOT NULL,
  BranchNo   INT NOT NULL,
  WorkHours  DECIMAL(5,2) NOT NULL CHECK (WorkHours >= 0),
  PRIMARY KEY (StaffID, BranchNo),
  FOREIGN KEY (StaffID) REFERENCES Staff(StaffID)
    ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (BranchNo) REFERENCES Branch(BranchNo)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Payment (
  PaymentNo    INT AUTO_INCREMENT PRIMARY KEY,
  PaymentType  VARCHAR(30) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE SalePayment (
  SaleID      INT NOT NULL,
  PaymentNo   INT NOT NULL,
  Amount      DECIMAL(12,2) NOT NULL CHECK (Amount >= 0),
  PRIMARY KEY (SaleID, PaymentNo),
  FOREIGN KEY (SaleID) REFERENCES SaleHeader(SaleID)
    ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY (PaymentNo) REFERENCES Payment(PaymentNo)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB; 

-- Trigger’lar
DELIMITER $$

CREATE TRIGGER trg_before_insert_saleline_stockcheck
BEFORE INSERT ON SaleLine
FOR EACH ROW
BEGIN
  DECLARE cur_stock INT;
  SELECT Amount INTO cur_stock
  FROM Stock
  WHERE BranchNo = (SELECT BranchNo FROM SaleHeader WHERE SaleID = NEW.SaleID)
    AND ProductID = NEW.ProductID;
  IF cur_stock IS NULL OR cur_stock < NEW.QuantitySold THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Yetersiz stok';
  END IF;
END$$

CREATE TRIGGER trg_before_update_saleline_stockcheck
BEFORE UPDATE ON SaleLine
FOR EACH ROW
BEGIN
  DECLARE cur_stock INT;
  DECLARE diff_qty INT;
  SET diff_qty = NEW.QuantitySold - OLD.QuantitySold;
  IF diff_qty > 0 THEN
    SELECT Amount INTO cur_stock
    FROM Stock
    WHERE BranchNo = (SELECT BranchNo FROM SaleHeader WHERE SaleID = OLD.SaleID)
      AND ProductID = OLD.ProductID;
    IF cur_stock IS NULL OR cur_stock < diff_qty THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Yetersiz stok';
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_after_insert_saleline
AFTER INSERT ON SaleLine
FOR EACH ROW
BEGIN
  DECLARE tax DECIMAL(5,2);
  DECLARE discount DECIMAL(5,2);
  DECLARE gross DECIMAL(12,2);
  DECLARE net DECIMAL(12,2);
  DECLARE br INT;
  DECLARE cust INT;

  SELECT BranchNo, CustomerID INTO br, cust
  FROM SaleHeader WHERE SaleID = NEW.SaleID;

  SELECT pt.TaxRate INTO tax
  FROM Product p JOIN ProductType pt ON p.ProductTypeID = pt.TypeID
  WHERE p.ProductID = NEW.ProductID;

  SELECT CustomerDiscount INTO discount
  FROM Customer WHERE CustomerID = cust;

  SET gross = NEW.QuantitySold * NEW.UnitPrice * (1 + tax/100);
  SET net = gross * (1 - discount/100);

  UPDATE Stock SET Amount = Amount - NEW.QuantitySold
  WHERE BranchNo = br AND ProductID = NEW.ProductID;

  UPDATE SaleHeader SET TotalAmount = TotalAmount + net
  WHERE SaleID = NEW.SaleID;
END$$

CREATE TRIGGER trg_after_update_saleline
AFTER UPDATE ON SaleLine
FOR EACH ROW
BEGIN
  DECLARE tax_old DECIMAL(5,2);
  DECLARE tax_new DECIMAL(5,2);
  DECLARE discount DECIMAL(5,2);
  DECLARE old_total DECIMAL(12,2);
  DECLARE new_total DECIMAL(12,2);
  DECLARE diff_qty INT;
  DECLARE br INT;
  DECLARE cust INT;

  SELECT BranchNo, CustomerID INTO br, cust
  FROM SaleHeader WHERE SaleID = NEW.SaleID;

  SELECT pt.TaxRate INTO tax_old
  FROM Product p JOIN ProductType pt ON p.ProductTypeID = pt.TypeID
  WHERE p.ProductID = OLD.ProductID;

  SELECT pt.TaxRate INTO tax_new
  FROM Product p JOIN ProductType pt ON p.ProductTypeID = pt.TypeID
  WHERE p.ProductID = NEW.ProductID;

  SELECT CustomerDiscount INTO discount
  FROM Customer WHERE CustomerID = cust;

  SET old_total = OLD.QuantitySold * OLD.UnitPrice * (1 + tax_old/100) * (1 - discount/100);
  SET new_total = NEW.QuantitySold * NEW.UnitPrice * (1 + tax_new/100) * (1 - discount/100);
  SET diff_qty = NEW.QuantitySold - OLD.QuantitySold;

  UPDATE Stock SET Amount = Amount - diff_qty
  WHERE BranchNo = br AND ProductID = NEW.ProductID;

  UPDATE SaleHeader SET TotalAmount = TotalAmount + (new_total - old_total)
  WHERE SaleID = NEW.SaleID;
END$$

CREATE TRIGGER trg_after_delete_saleline
AFTER DELETE ON SaleLine
FOR EACH ROW
BEGIN
  DECLARE tax DECIMAL(5,2);
  DECLARE discount DECIMAL(5,2);
  DECLARE gross DECIMAL(12,2);
  DECLARE net DECIMAL(12,2);
  DECLARE br INT;
  DECLARE cust INT;

  SELECT BranchNo, CustomerID INTO br, cust
  FROM SaleHeader WHERE SaleID = OLD.SaleID;

  SELECT pt.TaxRate INTO tax
  FROM Product p JOIN ProductType pt ON p.ProductTypeID = pt.TypeID
  WHERE p.ProductID = OLD.ProductID;

  SELECT CustomerDiscount INTO discount
  FROM Customer WHERE CustomerID = cust;

  SET gross = OLD.QuantitySold * OLD.UnitPrice * (1 + tax/100);
  SET net = gross * (1 - discount/100);

  UPDATE Stock SET Amount = Amount + OLD.QuantitySold
  WHERE BranchNo = br AND ProductID = OLD.ProductID;

  UPDATE SaleHeader SET TotalAmount = TotalAmount - net
  WHERE SaleID = OLD.SaleID;
END$$

DELIMITER ;

DROP TRIGGER IF EXISTS trg_before_insert_saleline_autoprice;
DELIMITER $$

CREATE TRIGGER trg_before_insert_saleline_autoprice
BEFORE INSERT ON SaleLine
FOR EACH ROW
BEGIN
  DECLARE product_price DECIMAL(10,2);

  IF NEW.UnitPrice = 0 THEN
    SELECT Price INTO product_price
    FROM Product
    WHERE ProductID = NEW.ProductID;

    SET NEW.UnitPrice = product_price;
  END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE TRIGGER trg_before_update_saleline_autoprice
BEFORE UPDATE ON SaleLine
FOR EACH ROW
BEGIN
  DECLARE product_price DECIMAL(10,2);

  IF NEW.UnitPrice = 0 THEN
    SELECT Price INTO product_price
    FROM Product
    WHERE ProductID = NEW.ProductID;

    SET NEW.UnitPrice = product_price;
  END IF;
END$$

DELIMITER ;

INSERT INTO Staff (Name, Surname, BirthDate, SuperID, Salary, Gender) VALUES
('Ahmet', 'Yılmaz', '1990-01-01', NULL, 6000.00, 'M');
INSERT INTO Staff (Name, Surname, BirthDate, SuperID, Salary, Gender) VALUES
('Ayşe', 'Kara', '1991-02-02', 1, 5800.00, 'F'),
('Mehmet', 'Demir', '1989-03-03', 1, 5900.00, 'M');

INSERT INTO Staff (Name, Surname, BirthDate, SuperID, Salary, Gender) VALUES
('Ali', 'Kaya', '1985-01-10', 1, 6200.00, 'M'),
('Fatma', 'Çelik', '1992-03-15', 2, 5800.00, 'F'),
('Can', 'Yıldız', '1993-04-12', 3, 6100.00, 'M'),
('Zeynep', 'Aslan', '1994-05-21', 1, 5950.00, 'F'),
('Murat', 'Koç', '1990-07-19', 2, 6300.00, 'M'),
('Elif', 'Aydın', '1991-09-13', 3, 6000.00, 'F'),
('Hasan', 'Demir', '1995-11-23', 1, 5700.00, 'M'),
('Sevgi', 'Turan', '1988-06-30', 2, 6500.00, 'F'),
('Kerem', 'Şahin', '1996-02-17', 3, 6100.00, 'M'),
('Derya', 'Öztürk', '1997-08-08', 1, 6200.00, 'F');


INSERT INTO Branch (BranchName, Location, MgrID) VALUES
('Ankara Şubesi', 'Ankara', 1),
('İzmir Şubesi', 'İzmir', 2),
('İstanbul Şubesi', 'İstanbul', 3);

INSERT INTO Branch (BranchName, Location, MgrID) VALUES
('Adana Şubesi', 'Adana', 4),
('Bursa Şubesi', 'Bursa', 5),
('Antalya Şubesi', 'Antalya', 6),
('Trabzon Şubesi', 'Trabzon', 7),
('Kayseri Şubesi', 'Kayseri', 8),
('Samsun Şubesi', 'Samsun', 9),
('Denizli Şubesi', 'Denizli', 10),
('Eskişehir Şubesi', 'Eskişehir', 11),
('Mersin Şubesi', 'Mersin', 12),
('Malatya Şubesi', 'Malatya', 13);


INSERT INTO Customer (RegisterDate, CustomerDiscount) VALUES
('2022-05-07', 0.09),
('2021-10-09', 12.64),
('2023-08-22', 11.29);

INSERT INTO Customer (RegisterDate, CustomerDiscount) VALUES
('2021-02-15', 5.30),
('2020-11-10', 2.75),
('2022-04-22', 9.40),
('2023-01-03', 3.95),
('2020-07-19', 0.00),
('2022-08-08', 6.60),
('2021-12-31', 12.50),
('2023-05-27', 1.25),
('2024-01-15', 10.10),
('2022-03-30', 4.00);

INSERT INTO Works (StaffID, BranchNo, WorkHours) VALUES
(4, 4, 35.5),
(5, 5, 38.0),
(6, 6, 32.75),
(7, 7, 40.25),
(8, 8, 36.0),
(9, 9, 39.5),
(10, 10, 34.0),
(11, 11, 37.25),
(12, 12, 30.0),
(13, 13, 33.5);


INSERT INTO ProductType (TypeName, ReorderLevel, TaxRate) VALUES
('İçecek', 10, 8.00),
('Kuru Gıda', 20, 12.00);
INSERT INTO ProductType (TypeName, ReorderLevel, TaxRate) VALUES
('Süt Ürünleri', 15, 8.00),
('Et Ürünleri', 20, 12.00),
('Temizlik Ürünleri', 10, 18.00),
('Atıştırmalıklar', 20, 15.00),
('Meyve', 10, 1.00),
('Sebze', 10, 1.00),
('Unlu Mamuller', 12, 5.00),
('Konserve', 20, 8.00);



INSERT INTO Product (ProductName, ProductTypeID, BarcodeNumber, Price) VALUES
('Çay', 1, 'TRN001', 50.00),
('Pirinç', 2, 'TRN002', 40.00);
INSERT INTO Product (ProductName, ProductTypeID, BarcodeNumber, Price) VALUES
('Süt', 1, 'TRN101', 25.00),
('Yoğurt', 1, 'TRN102', 18.50),
('Dana Eti', 2, 'TRN103', 120.00),
('Deterjan', 3, 'TRN104', 55.00),
('Meyve Suyu', 4, 'TRN105', 15.00),
('Mercimek', 5, 'TRN106', 22.00),
('Cips', 6, 'TRN107', 14.75),
('Elma', 7, 'TRN108', 5.50),
('Domates', 8, 'TRN109', 6.00),
('Ekmek', 9, 'TRN110', 4.00);


INSERT INTO Stock (BranchNo, ProductID, Amount) VALUES
(1, 1, 100), (1, 2, 100),
(2, 1, 100), (2, 2, 100),
(3, 1, 100), (3, 2, 100);

INSERT INTO Stock (BranchNo, ProductID, Amount) VALUES
(4, 4, 50),
(5, 5, 60),
(6, 6, 40),
(7, 7, 100),
(8, 8, 75),
(9, 9, 30),
(10, 10, 200),
(11, 1, 150),
(12, 2, 80),
(13, 3, 90);


INSERT INTO SaleHeader (BranchNo, CustomerID, StaffID) VALUES
(1, 1, 1),
(2, 2, 2),
(3, 3, 3);

INSERT INTO SaleHeader (BranchNo, CustomerID, StaffID) VALUES
(4, 4, 4),
(5, 5, 5),
(6, 6, 6),
(7, 7, 7),
(8, 8, 8),
(9, 9, 9),
(10, 10, 10),
(11, 11, 11),
(12, 12, 12),
(13, 13, 13);


INSERT INTO SaleLine (SaleID, ProductID, QuantitySold, UnitPrice) VALUES
(1, 1, 2, 0), 
(2, 2, 3, 0), 
(3, 1, 1, 0); 

INSERT INTO SaleLine (SaleID, ProductID, QuantitySold, UnitPrice) VALUES
(4, 4, 2, 0),
(5, 5, 3, 0),
(6, 6, 1, 0),
(7, 7, 4, 0),
(8, 8, 5, 0),
(9, 9, 6, 0),
(10, 10, 10, 0),
(11, 1, 3, 0),
(12, 2, 2, 0),
(13, 3, 1, 0);


INSERT INTO Payment (PaymentType) VALUES
('Nakit'), ('Kredi Kartı');
INSERT INTO Payment (PaymentType) VALUES
('Havale'),
('Mobil Ödeme'),
('Yemek Kartı'),
('Sodexo'),
('Multinet'),
('Trink'),
('Troy'),
('Banka Kartı');


INSERT INTO SalePayment (SaleID, PaymentNo, Amount) VALUES
(1, 1, 95.00),
(2, 2, 134.40),
(3, 1, 54.00);

INSERT INTO SalePayment (SaleID, PaymentNo, Amount) VALUES
(4, 3, 129.80),
(5, 4, 50.50),
(6, 5, 24.64),
(7, 6, 68.20),
(8, 7, 41.25),
(9, 8, 46.80),
(10, 9, 66.00),
(11, 10, 75.00),
(12, 1, 36.00),
(13, 2, 110.00);

