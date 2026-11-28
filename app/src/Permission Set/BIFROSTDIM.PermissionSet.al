namespace Origo.Bifrost.Dimensions;

using Microsoft.Assembly.History;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.FixedAssets.Insurance;
using Microsoft.FixedAssets.Ledger;
using Microsoft.FixedAssets.Maintenance;
using Microsoft.Inventory.Counting.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Projects.Project.WIP;
using Microsoft.Projects.Resources.Ledger;
using Microsoft.Purchases.History;
using Microsoft.Purchases.Payables;
using Microsoft.Sales.FinanceCharge;
using Microsoft.Sales.History;
using Microsoft.Sales.Receivables;
using Microsoft.Sales.Reminder;
using Microsoft.Service.History;
using Microsoft.Service.Ledger;

/// <summary>
/// Grants Bifrost Dimensions execution and read access to the posted ledgers, posted documents and dimension sets the message types read.
/// </summary>
permissionset 10076486 "BIFROST DIM ori"
{
    Assignable = true;
    Access = Public;
    Caption = 'Bifrost Dimensions', MaxLength = 30, Comment = 'is-IS=Bifröst - víddir';
    Permissions =
        tabledata "G/L Entry" = R,
        tabledata "Cust. Ledger Entry" = R,
        tabledata "Vendor Ledger Entry" = R,
        tabledata "Bank Account Ledger Entry" = R,
        tabledata "Item Ledger Entry" = R,
        tabledata "Value Entry" = R,
        tabledata "FA Ledger Entry" = R,
        tabledata "Maintenance Ledger Entry" = R,
        tabledata "Ins. Coverage Ledger Entry" = R,
        tabledata "Capacity Ledger Entry" = R,
        tabledata "Res. Ledger Entry" = R,
        tabledata "Job Ledger Entry" = R,
        tabledata "Job WIP Entry" = R,
        tabledata "Job WIP G/L Entry" = R,
        tabledata "Service Ledger Entry" = R,
        tabledata "Warranty Ledger Entry" = R,
        tabledata "Phys. Inventory Ledger Entry" = R,
        tabledata "Sales Shipment Header" = R,
        tabledata "Sales Shipment Line" = R,
        tabledata "Sales Invoice Header" = R,
        tabledata "Sales Invoice Line" = R,
        tabledata "Sales Cr.Memo Header" = R,
        tabledata "Sales Cr.Memo Line" = R,
        tabledata "Return Receipt Header" = R,
        tabledata "Return Receipt Line" = R,
        tabledata "Purch. Rcpt. Header" = R,
        tabledata "Purch. Rcpt. Line" = R,
        tabledata "Purch. Inv. Header" = R,
        tabledata "Purch. Inv. Line" = R,
        tabledata "Purch. Cr. Memo Hdr." = R,
        tabledata "Purch. Cr. Memo Line" = R,
        tabledata "Return Shipment Header" = R,
        tabledata "Return Shipment Line" = R,
        tabledata "Transfer Shipment Header" = R,
        tabledata "Transfer Shipment Line" = R,
        tabledata "Transfer Receipt Header" = R,
        tabledata "Transfer Receipt Line" = R,
        tabledata "Service Shipment Header" = R,
        tabledata "Service Shipment Line" = R,
        tabledata "Service Invoice Header" = R,
        tabledata "Service Invoice Line" = R,
        tabledata "Service Cr.Memo Header" = R,
        tabledata "Service Cr.Memo Line" = R,
        tabledata "Issued Reminder Header" = R,
        tabledata "Issued Reminder Line" = R,
        tabledata "Issued Fin. Charge Memo Header" = R,
        tabledata "Issued Fin. Charge Memo Line" = R,
        tabledata "Posted Assembly Header" = R,
        tabledata "Posted Assembly Line" = R,
        tabledata "Production Order" = R,
        tabledata "Prod. Order Line" = R,
        tabledata "Dimension" = R,
        tabledata "Dimension Set Entry" = R,
        codeunit "Dimensions Registration ori" = X,
        codeunit "Dim Target Registry ori" = X,
        codeunit "Dimensions Find Impl ori" = X;
}
