---

# 🛒 Supermarket Database Project

This project contains the SQL schema and sample data for a **supermarket management database**.
The database is designed to manage staff, branches, products, stock, sales, and payments with proper relational integrity and business rules enforced using triggers.

---

## 📌 Database Overview

Database name:

```
supermarket3
```

The system models a real-world supermarket structure including:

* Employees and supervisors
* Branches and managers
* Products and product types
* Stock tracking per branch
* Customers and discounts
* Sales transactions
* Multiple payment methods
* Automatic stock and total amount calculations using triggers

---

## 🧱 Technologies

* MySQL / MariaDB
* InnoDB storage engine
* SQL triggers for business logic
* UTF-8 character encoding

---

## 🗄️ Schema Structure

### Main Tables

* **Staff**
  Stores employee information and supervisor relationships

* **Branch**
  Stores branch details and branch managers

* **ProductType**
  Product categories with tax rate and reorder level

* **Product**
  Individual products with price and barcode

* **Stock**
  Tracks product quantity per branch

* **Customer**
  Customer registration date and discount rate

* **SaleHeader**
  Sale transaction header information

* **SaleLine**
  Products sold per sale

* **Payment**
  Available payment types

* **SalePayment**
  Payment breakdown per sale

* **Works**
  Staff working hours per branch

---

## 🔗 Relationships

* Staff can supervise other staff
* Each branch has one manager
* Products belong to a product type
* Stock is tracked per branch and product
* A sale is linked to a branch, staff member, and customer
* Sales can have multiple products and multiple payment methods

---

## ⚙️ Triggers & Business Logic

The database includes triggers to enforce business rules:

* Prevent sales if stock is insufficient
* Automatically update stock after sale insert, update, or delete
* Automatically calculate sale total amount with tax and customer discount
* Automatically assign product price if unit price is set to zero
* Keep `SaleHeader.TotalAmount` consistent at all times

---

## 🧪 Sample Data

The script includes sample data for:

* Staff members
* Branches
* Customers
* Products and product types
* Stock quantities
* Sales, sale lines, and payments

This allows the database to be tested immediately after setup.

---

## ▶️ Setup Instructions

### 1️⃣ Create Database

```sql
CREATE DATABASE supermarket3
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
```

---

### 2️⃣ Run SQL Script

Run the full SQL script in order using:

* MySQL Workbench
* phpMyAdmin
* Command line MySQL client

---

### 3️⃣ Verify

Example checks:

```sql
SELECT * FROM Staff;
SELECT * FROM Product;
SELECT * FROM SaleHeader;
SELECT * FROM Stock;
```

---

## 🔐 Constraints & Integrity

* Primary and foreign keys enforced
* Cascading updates and deletes where appropriate
* CHECK constraints for numeric validation
* ENUM used for gender field
* Composite primary keys used where required

---

## 🎯 Project Purpose

This database was created to demonstrate:

* Relational database design
* Use of foreign keys and constraints
* Trigger-based business logic
* Stock and sales consistency
* Realistic supermarket transaction modeling

---

## 👤 Author

**Salih Alper Çetin**

---
