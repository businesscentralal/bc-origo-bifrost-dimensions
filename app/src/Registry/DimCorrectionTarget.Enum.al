namespace Origo.Bifrost.Dimensions;

/// <summary>
/// The supported-table registry of Bifrost Dimensions: one value per posted ledger or posted document table.
/// Every value is described by the registry codeunit; extensions may add values with their own implementation.
/// </summary>
enum 10076492 "Dim. Correction Target ori" implements "Dim. Correction Target ori"
{
    Extensible = true;
    DefaultImplementation = "Dim. Correction Target ori" = "Dim Target Registry ori";
    UnknownValueImplementation = "Dim. Correction Target ori" = "Dim Target Registry ori";

    /// <summary>G/L Entry.</summary>
    value(1; "G/L Entry")
    {
        Caption = 'G/L Entry', Locked = true;
    }
    /// <summary>Cust. Ledger Entry.</summary>
    value(2; "Cust. Ledger Entry")
    {
        Caption = 'Cust. Ledger Entry', Locked = true;
    }
    /// <summary>Vendor Ledger Entry.</summary>
    value(3; "Vendor Ledger Entry")
    {
        Caption = 'Vendor Ledger Entry', Locked = true;
    }
    /// <summary>Bank Account Ledger Entry.</summary>
    value(4; "Bank Account Ledger Entry")
    {
        Caption = 'Bank Account Ledger Entry', Locked = true;
    }
    /// <summary>Item Ledger Entry.</summary>
    value(5; "Item Ledger Entry")
    {
        Caption = 'Item Ledger Entry', Locked = true;
    }
    /// <summary>Value Entry.</summary>
    value(6; "Value Entry")
    {
        Caption = 'Value Entry', Locked = true;
    }
    /// <summary>FA Ledger Entry.</summary>
    value(7; "FA Ledger Entry")
    {
        Caption = 'FA Ledger Entry', Locked = true;
    }
    /// <summary>Maintenance Ledger Entry.</summary>
    value(8; "Maintenance Ledger Entry")
    {
        Caption = 'Maintenance Ledger Entry', Locked = true;
    }
    /// <summary>Ins. Coverage Ledger Entry.</summary>
    value(9; "Ins. Coverage Ledger Entry")
    {
        Caption = 'Ins. Coverage Ledger Entry', Locked = true;
    }
    /// <summary>Capacity Ledger Entry.</summary>
    value(10; "Capacity Ledger Entry")
    {
        Caption = 'Capacity Ledger Entry', Locked = true;
    }
    /// <summary>Res. Ledger Entry.</summary>
    value(11; "Res. Ledger Entry")
    {
        Caption = 'Res. Ledger Entry', Locked = true;
    }
    /// <summary>Job Ledger Entry.</summary>
    value(12; "Job Ledger Entry")
    {
        Caption = 'Job Ledger Entry', Locked = true;
    }
    /// <summary>Job WIP Entry.</summary>
    value(13; "Job WIP Entry")
    {
        Caption = 'Job WIP Entry', Locked = true;
    }
    /// <summary>Job WIP G/L Entry.</summary>
    value(14; "Job WIP G/L Entry")
    {
        Caption = 'Job WIP G/L Entry', Locked = true;
    }
    /// <summary>Service Ledger Entry.</summary>
    value(15; "Service Ledger Entry")
    {
        Caption = 'Service Ledger Entry', Locked = true;
    }
    /// <summary>Warranty Ledger Entry.</summary>
    value(16; "Warranty Ledger Entry")
    {
        Caption = 'Warranty Ledger Entry', Locked = true;
    }
    /// <summary>Phys. Inventory Ledger Entry.</summary>
    value(17; "Phys. Inventory Ledger Entry")
    {
        Caption = 'Phys. Inventory Ledger Entry', Locked = true;
    }
    /// <summary>Sales Shipment (header and lines).</summary>
    value(18; "Sales Shipment")
    {
        Caption = 'Sales Shipment', Locked = true;
    }
    /// <summary>Sales Invoice (header and lines).</summary>
    value(19; "Sales Invoice")
    {
        Caption = 'Sales Invoice', Locked = true;
    }
    /// <summary>Sales Cr.Memo (header and lines).</summary>
    value(20; "Sales Cr.Memo")
    {
        Caption = 'Sales Cr.Memo', Locked = true;
    }
    /// <summary>Return Receipt (header and lines).</summary>
    value(21; "Return Receipt")
    {
        Caption = 'Return Receipt', Locked = true;
    }
    /// <summary>Purch. Rcpt. (header and lines).</summary>
    value(22; "Purch. Rcpt.")
    {
        Caption = 'Purch. Rcpt.', Locked = true;
    }
    /// <summary>Purch. Inv. (header and lines).</summary>
    value(23; "Purch. Inv.")
    {
        Caption = 'Purch. Inv.', Locked = true;
    }
    /// <summary>Purch. Cr. Memo (header and lines).</summary>
    value(24; "Purch. Cr. Memo")
    {
        Caption = 'Purch. Cr. Memo', Locked = true;
    }
    /// <summary>Return Shipment (header and lines).</summary>
    value(25; "Return Shipment")
    {
        Caption = 'Return Shipment', Locked = true;
    }
    /// <summary>Transfer Shipment (header and lines).</summary>
    value(26; "Transfer Shipment")
    {
        Caption = 'Transfer Shipment', Locked = true;
    }
    /// <summary>Transfer Receipt (header and lines).</summary>
    value(27; "Transfer Receipt")
    {
        Caption = 'Transfer Receipt', Locked = true;
    }
    /// <summary>Service Shipment (header and lines).</summary>
    value(28; "Service Shipment")
    {
        Caption = 'Service Shipment', Locked = true;
    }
    /// <summary>Service Invoice (header and lines).</summary>
    value(29; "Service Invoice")
    {
        Caption = 'Service Invoice', Locked = true;
    }
    /// <summary>Service Cr.Memo (header and lines).</summary>
    value(30; "Service Cr.Memo")
    {
        Caption = 'Service Cr.Memo', Locked = true;
    }
    /// <summary>Issued Reminder (header and lines).</summary>
    value(31; "Issued Reminder")
    {
        Caption = 'Issued Reminder', Locked = true;
    }
    /// <summary>Issued Fin. Charge Memo (header and lines).</summary>
    value(32; "Issued Fin. Charge Memo")
    {
        Caption = 'Issued Fin. Charge Memo', Locked = true;
    }
    /// <summary>Posted Assembly Header (header and lines).</summary>
    value(33; "Posted Assembly Header")
    {
        Caption = 'Posted Assembly Header', Locked = true;
    }
    /// <summary>Production Order (header and lines).</summary>
    value(34; "Production Order")
    {
        Caption = 'Production Order', Locked = true;
    }
}
