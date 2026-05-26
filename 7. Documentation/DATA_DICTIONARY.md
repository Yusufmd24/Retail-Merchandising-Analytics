# Data Dictionary

## Data Model



This project uses a retail merchandising star schema.



## Fact Table: Sales



|Column|Description|
|-|-|
|transaction\_id|Unique transaction ID|
|transaction\_date|Sales date|
|item\_id|Product SKU|
|vendor\_id|Vendor ID|
|store\_id|Store ID|
|quantity\_sold|Units sold|
|sales\_revenue|Revenue|
|inventory\_units|Inventory|
|margin\_pct|Margin %|

## 

## Dimension: Items



|Column|Description|
|-|-|
|item\_id|SKU|
|item\_name|Product name|
|category|Product category|
|department|Department|
|brand|Brand|
|price\_segment|Pricing tier|

## 

## Dimension: Vendors



|Column|Description|
|-|-|
|vendor\_id|Vendor ID|
|vendor\_name|Vendor|
|lead\_time\_days|Replenishment lead time|
|dependency\_risk|Vendor dependency classification|

## 

## Relationships



* Sales\[item\_id] → Items\[item\_id]
* Sales\[vendor\_id] → Vendors\[vendor\_id]
* Sales\[transaction\_date] → Date\[date]





## Core Measures



```DAX


Total Revenue = SUM(Sales\\\[sales\\\_revenue])


Total Units = SUM(Sales\\\[quantity\\\_sold])


Avg Margin % = AVERAGE(Sales\\\[margin\\\_pct])


Inventory Turnover = DIVIDE(\\\[Total Units], SUM(Sales\\\[inventory\\\_units]))


```

