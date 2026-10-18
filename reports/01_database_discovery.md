# AdventureWorks2022 database discovery

## Scope and method

The metadata queries in [01_database_structure.sql](../sql/01_exploration/01_database_structure.sql) were executed against the configured `AdventureWorks2022` database. They read SQL Server catalog metadata only; no database data was changed. The checks returned the schemas, user tables, focused column definitions, primary keys, and foreign-key mappings below.

## Schemas and relevant tables

The catalog returned application schemas `dbo`, `HumanResources`, `Person`, `Production`, `Purchasing`, and `Sales`, as well as SQL Server metadata schemas `guest`, `INFORMATION_SCHEMA`, and `sys`.

Relevant tables present in the inventory:

| Schema | Verified tables | Purpose in discovery |
|---|---|---|
| `Sales` | `Customer`, `SalesOrderHeader`, `SalesOrderDetail`, `SalesTerritory`, `SalesTerritoryHistory`, `Store`, `SpecialOfferProduct` | Customer entity, order header and lines, territory, business customer, and the product/offer bridge used by order lines |
| `Person` | `Person`, `Address`, `BusinessEntity`, `StateProvince`, `CountryRegion` | Individual customer details and geographic descriptors |
| `Production` | `Product`, `ProductSubcategory`, `ProductCategory` | Products and the product hierarchy |

The inventory also includes many additional tables in the same schemas; the list above focuses on the customer analytics path and related lookups.

## Verified keys and important columns

The focused metadata query confirmed these primary keys:

| Table | Primary key |
|---|---|
| `Sales.Customer` | `CustomerID` |
| `Sales.SalesOrderHeader` | `SalesOrderID` |
| `Sales.SalesOrderDetail` | (`SalesOrderID`, `SalesOrderDetailID`) |
| `Production.Product` | `ProductID` |
| `Production.ProductSubcategory` | `ProductSubcategoryID` |
| `Production.ProductCategory` | `ProductCategoryID` |
| `Sales.SalesTerritory` | `TerritoryID` |
| `Person.Person` | `BusinessEntityID` |
| `Sales.Store` | `BusinessEntityID` |
| `Sales.SpecialOfferProduct` | (`SpecialOfferID`, `ProductID`) |

Important confirmed columns include:

- `Sales.Customer`: `CustomerID`, nullable `PersonID`, nullable `StoreID`, nullable `TerritoryID`, `AccountNumber`.
- `Sales.SalesOrderHeader`: `SalesOrderID`, `OrderDate`, `DueDate`, nullable `ShipDate`, `Status`, `CustomerID`, nullable `TerritoryID`, `SubTotal`, `TaxAmt`, `Freight`, `TotalDue`.
- `Sales.SalesOrderDetail`: `SalesOrderID`, `SalesOrderDetailID`, `OrderQty`, `ProductID`, `SpecialOfferID`, `UnitPrice`, `UnitPriceDiscount`, `LineTotal`.
- `Production.Product`: `ProductID`, `ProductNumber`, nullable `ProductSubcategoryID`, `ListPrice`, `StandardCost`, `SellStartDate`, nullable `SellEndDate` and `DiscontinuedDate`.
- `Production.ProductSubcategory`: `ProductSubcategoryID`, `ProductCategoryID`.
- `Production.ProductCategory`: `ProductCategoryID`.
- `Sales.SalesTerritory`: `TerritoryID`, `CountryRegionCode`, `Group`.
- `Person.Person`: `BusinessEntityID`, `PersonType`.
- `Sales.SalesTerritoryHistory`: `BusinessEntityID`, `TerritoryID`, `StartDate`, nullable `EndDate`.

The catalog output also returned data types and nullability. For example, order and customer identifiers are `int`, order dates are `datetime`, and order amounts are `money`; the full column inventory query is retained in the SQL file for further inspection.

## Verified foreign keys and relationships

| Child column(s) | References | Relationship use |
|---|---|---|
| `Sales.SalesOrderHeader.CustomerID` | `Sales.Customer.CustomerID` | Customer to orders |
| `Sales.SalesOrderDetail.SalesOrderID` | `Sales.SalesOrderHeader.SalesOrderID` | Order to line items |
| `Sales.SalesOrderDetail.(SpecialOfferID, ProductID)` | `Sales.SpecialOfferProduct.(SpecialOfferID, ProductID)` | Order line to its offer/product combination |
| `Sales.SpecialOfferProduct.ProductID` | `Production.Product.ProductID` | Offer/product bridge to product |
| `Production.Product.ProductSubcategoryID` | `Production.ProductSubcategory.ProductSubcategoryID` | Product to subcategory (nullable on product) |
| `Production.ProductSubcategory.ProductCategoryID` | `Production.ProductCategory.ProductCategoryID` | Subcategory to category |
| `Sales.Customer.PersonID` | `Person.Person.BusinessEntityID` | Individual customer to person record (nullable) |
| `Sales.Customer.StoreID` | `Sales.Store.BusinessEntityID` | Customer to store record (nullable) |
| `Sales.Customer.TerritoryID` | `Sales.SalesTerritory.TerritoryID` | Customer territory assignment (nullable) |
| `Sales.SalesOrderHeader.TerritoryID` | `Sales.SalesTerritory.TerritoryID` | Territory recorded on each order (nullable) |
| `Sales.SalesTerritory.CountryRegionCode` | `Person.CountryRegion.CountryRegionCode` | Territory country/region |

Additional verified geographic paths are `Person.Address.StateProvinceID` to `Person.StateProvince.StateProvinceID`, and `Person.StateProvince.TerritoryID` to `Sales.SalesTerritory.TerritoryID`. Order bill-to and ship-to address columns also reference `Person.Address.AddressID`.

`Sales.SalesTerritoryHistory` is linked to `Sales.SalesPerson` by `BusinessEntityID` and to `Sales.SalesTerritory` by `TerritoryID`. It records salesperson territory history; it is not a customer territory history table.

## Proposed customer analytics model

Use one customer row as the customer dimension, one order-header row as the order grain, and one order-detail row as the purchased line grain. The relationship chain for purchase behavior is:

1. `Sales.Customer.CustomerID` → `Sales.SalesOrderHeader.CustomerID`.
2. `Sales.SalesOrderHeader.SalesOrderID` → `Sales.SalesOrderDetail.SalesOrderID`.
3. For product attributes, order detail joins to `Sales.SpecialOfferProduct` on **both** `SpecialOfferID` and `ProductID`; that bridge references `Production.Product` by `ProductID`.
4. `Production.Product.ProductSubcategoryID` → `Production.ProductSubcategory.ProductSubcategoryID` → `Production.ProductCategory.ProductCategoryID`.
5. Customer territory can be read from the customer's `TerritoryID`; an order also has its own `TerritoryID`. Preserve both if the question needs the customer's assigned territory and the territory recorded on a specific transaction.
6. For customer identity, join to `Person.Person` or `Sales.Store` through the nullable customer keys. Keep both routes optional because not every customer row is tied through both columns.

At the line grain, `OrderQty`, `UnitPrice`, `UnitPriceDiscount`, and `LineTotal` are present. Header fields `SubTotal`, `TaxAmt`, `Freight`, and `TotalDue` are also present. Choosing a revenue definition, handling order status, and deciding how to treat taxes, freight, discounts, or returns belong to the later metric-definition phase; no KPI is calculated here.

### Text relationship diagram

```text
Sales.Customer ──< Sales.SalesOrderHeader ──< Sales.SalesOrderDetail
      │                       │                           │
      ├── Person.Person       └── Sales.SalesTerritory     └── Sales.SpecialOfferProduct
      ├── Sales.Store                                          │
      └── Sales.SalesTerritory                                 └── Production.Product
                                                                    │
                                              ProductSubcategory ───┘
                                                    │
                                              ProductCategory

Sales.SalesTerritory ── Person.CountryRegion
Person.Address ── Person.StateProvince ── Sales.SalesTerritory
Sales.SalesTerritoryHistory ── Sales.SalesPerson (employee territory history)
```

Each `──<` represents a parent-to-many-child relationship in the proposed analytical path. The arrows follow the verified foreign-key column mappings; product lookup passes through `SpecialOfferProduct` because that is how the order-detail foreign key is defined.

## Discovery notes

- The order-detail table does **not** have a direct foreign key to `Production.Product`. It references the composite key of `Sales.SpecialOfferProduct`, which then references `Product`. The product join must use this bridge or deliberately document an alternative join that does not enforce the recorded offer/product pairing.
- Territory is available both on the customer and order header. These are distinct assignments and should not be silently treated as interchangeable.
- The history table is salesperson territory history, not customer territory history.
- Customer identity has two optional relationship paths: `PersonID` and `StoreID`.

This report stops at database structure and proposed data model. It contains no KPI calculations, churn analysis, or machine-learning work.
