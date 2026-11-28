namespace Origo.Bifrost.Dimensions;

/// <summary>
/// Describes every supported posted ledger and posted document table: table numbers, field names, the line table and
/// the header-to-line link. Fields are named, not numbered, and resolved against the installed table, so a renamed
/// field shows up in the registry guard test instead of silently reading the wrong column.
/// </summary>
codeunit 10076493 "Dim Target Registry ori" implements "Dim. Correction Target ori"
{
    Access = Internal;

    /// <summary>Describes one registry target as a JSON object (names, table numbers, field names, line link).</summary>
    /// <param name="Target">The registry value to describe.</param>
    /// <returns>The descriptor; empty when the target is not known to this registry.</returns>
    procedure Describe(Target: Enum "Dim. Correction Target ori") Descriptor: JsonObject
    begin
        case Target of
            Target::"G/L Entry":
                Descriptor := Ledger(Target, 17, 'Source No.');
            Target::"Cust. Ledger Entry":
                Descriptor := Ledger(Target, 21, 'Customer No.');
            Target::"Vendor Ledger Entry":
                Descriptor := Ledger(Target, 25, 'Vendor No.');
            Target::"Bank Account Ledger Entry":
                Descriptor := Ledger(Target, 271, 'Bank Account No.');
            Target::"Item Ledger Entry":
                Descriptor := Ledger(Target, 32, 'Item No.');
            Target::"Value Entry":
                Descriptor := Ledger(Target, 5802, 'Item No.');
            Target::"FA Ledger Entry":
                Descriptor := Ledger(Target, 5601, 'FA No.');
            Target::"Maintenance Ledger Entry":
                Descriptor := Ledger(Target, 5625, 'FA No.');
            Target::"Ins. Coverage Ledger Entry":
                Descriptor := Ledger(Target, 5629, 'FA No.');
            Target::"Capacity Ledger Entry":
                Descriptor := Ledger(Target, 5832, 'No.');
            Target::"Res. Ledger Entry":
                Descriptor := Ledger(Target, 203, 'Resource No.');
            Target::"Job Ledger Entry":
                Descriptor := Ledger(Target, 169, 'Job No.');
            Target::"Job WIP Entry":
                Descriptor := Ledger(Target, 1004, 'Job No.');
            Target::"Job WIP G/L Entry":
                Descriptor := Ledger(Target, 1005, 'Job No.');
            Target::"Service Ledger Entry":
                Descriptor := Ledger(Target, 5907, 'Customer No.');
            Target::"Warranty Ledger Entry":
                Descriptor := Ledger(Target, 5908, 'Customer No.');
            Target::"Phys. Inventory Ledger Entry":
                Descriptor := Ledger(Target, 281, 'Item No.');
            Target::"Sales Shipment":
                Descriptor := Document(Target, 110, 'Sell-to Customer No.', 111, 'Document No.');
            Target::"Sales Invoice":
                Descriptor := Document(Target, 112, 'Sell-to Customer No.', 113, 'Document No.');
            Target::"Sales Cr.Memo":
                Descriptor := Document(Target, 114, 'Sell-to Customer No.', 115, 'Document No.');
            Target::"Return Receipt":
                Descriptor := Document(Target, 6660, 'Sell-to Customer No.', 6661, 'Document No.');
            Target::"Purch. Rcpt.":
                Descriptor := Document(Target, 120, 'Buy-from Vendor No.', 121, 'Document No.');
            Target::"Purch. Inv.":
                Descriptor := Document(Target, 122, 'Buy-from Vendor No.', 123, 'Document No.');
            Target::"Purch. Cr. Memo":
                Descriptor := Document(Target, 124, 'Buy-from Vendor No.', 125, 'Document No.');
            Target::"Return Shipment":
                Descriptor := Document(Target, 6650, 'Buy-from Vendor No.', 6651, 'Document No.');
            Target::"Transfer Shipment":
                Descriptor := Document(Target, 5744, 'Transfer-from Code', 5745, 'Document No.');
            Target::"Transfer Receipt":
                Descriptor := Document(Target, 5746, 'Transfer-from Code', 5747, 'Document No.');
            Target::"Service Shipment":
                Descriptor := Document(Target, 5990, 'Customer No.', 5991, 'Document No.');
            Target::"Service Invoice":
                Descriptor := Document(Target, 5992, 'Customer No.', 5993, 'Document No.');
            Target::"Service Cr.Memo":
                Descriptor := Document(Target, 5994, 'Customer No.', 5995, 'Document No.');
            Target::"Issued Reminder":
                Descriptor := Document(Target, 297, 'Customer No.', 298, 'Reminder No.');
            Target::"Issued Fin. Charge Memo":
                Descriptor := Document(Target, 304, 'Customer No.', 305, 'Finance Charge Memo No.');
            Target::"Posted Assembly Header":
                Descriptor := Document(Target, 910, 'Item No.', 911, 'Document No.');
            Target::"Production Order":
                Descriptor := Document(Target, 5405, 'Source No.', 5406, 'Prod. Order No.');
        end;
        if Descriptor.Contains('tableNo') then begin
            if Target = Target::"Job WIP Entry" then begin
                Descriptor.Replace('postingDateField', 'WIP Posting Date');
            end;
            if Target = Target::"Production Order" then begin
                Descriptor.Replace('postingDateField', 'Finished Date');
                Descriptor.Add('statusField', 'Status');
                Descriptor.Add('statusValue', 4);
            end;
        end;
    end;

    local procedure Ledger(Target: Enum "Dim. Correction Target ori"; TableNo: Integer; SourceField: Text) Descriptor: JsonObject
    begin
        Descriptor := Common(Target, TableNo, 'Ledger', 'Entry No.', 'Document No.', SourceField);
    end;

    local procedure Document(Target: Enum "Dim. Correction Target ori"; TableNo: Integer; SourceField: Text; LineTableNo: Integer; LinkField: Text) Descriptor: JsonObject
    begin
        Descriptor := Common(Target, TableNo, 'Document', 'No.', 'No.', SourceField);
        Descriptor.Add('lineTableNo', LineTableNo);
        Descriptor.Add('lineLinkField', LinkField);
    end;

    local procedure Common(Target: Enum "Dim. Correction Target ori"; TableNo: Integer; Kind: Text; KeyField: Text; DocumentNoField: Text; SourceField: Text) Descriptor: JsonObject
    begin
        Descriptor.Add('name', Format(Target));
        Descriptor.Add('tableNo', TableNo);
        Descriptor.Add('kind', Kind);
        Descriptor.Add('keyField', KeyField);
        Descriptor.Add('documentNoField', DocumentNoField);
        Descriptor.Add('postingDateField', 'Posting Date');
        Descriptor.Add('sourceNoField', SourceField);
        Descriptor.Add('descriptionField', 'Description');
        Descriptor.Add('dimensionSetIdField', 'Dimension Set ID');
    end;

    /// <summary>Finds a registry value by its name, ignoring case.</summary>
    /// <param name="Name">The registry name, for example G/L Entry.</param>
    /// <param name="Target">Receives the registry value.</param>
    /// <returns>True when the name is a known, installed registry entry.</returns>
    procedure FindTarget(Name: Text; var Target: Enum "Dim. Correction Target ori"): Boolean
    var
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"Dim. Correction Target ori".Ordinals() do begin
            Target := Enum::"Dim. Correction Target ori".FromInteger(Ordinal);
            if (UpperCase(Format(Target)) = UpperCase(Name)) and IsAvailable(Target) then
                exit(true);
        end;
        exit(false);
    end;

    /// <summary>Lists the registry values whose tables are installed. Tables of an absent optional app are skipped silently.</summary>
    /// <param name="Targets">Receives the ordinals of the available registry values.</param>
    procedure ListAvailable(var Targets: List of [Integer])
    var
        Target: Enum "Dim. Correction Target ori";
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"Dim. Correction Target ori".Ordinals() do begin
            Target := Enum::"Dim. Correction Target ori".FromInteger(Ordinal);
            if IsAvailable(Target) then
                Targets.Add(Ordinal);
        end;
    end;

    /// <summary>Returns the valid registry names, comma separated.</summary>
    /// <returns>The names of the available registry values.</returns>
    procedure ValidNames() Names: Text
    var
        Targets: List of [Integer];
        Ordinal: Integer;
    begin
        ListAvailable(Targets);
        foreach Ordinal in Targets do begin
            if Names <> '' then
                Names += ', ';
            Names += Format(Enum::"Dim. Correction Target ori".FromInteger(Ordinal));
        end;
    end;

    /// <summary>Tells whether the table of a registry value exists in this environment.</summary>
    /// <param name="Target">The registry value.</param>
    /// <returns>True when the descriptor is known and its table can be opened.</returns>
    procedure IsAvailable(Target: Enum "Dim. Correction Target ori"): Boolean
    var
        Implementation: Interface "Dim. Correction Target ori";
        Descriptor: JsonObject;
        Token: JsonToken;
    begin
        Implementation := Target;
        Descriptor := Implementation.Describe(Target);
        if not Descriptor.Get('tableNo', Token) then
            exit(false);
        exit(TableExists(Token.AsValue().AsInteger()));
    end;

    /// <summary>Lists the global and shortcut dimension code fields (Global 1-2, Shortcut 1-8) that exist on a table.</summary>
    /// <param name="TableNo">The table to inspect.</param>
    /// <param name="FieldNames">Receives the names of the dimension code fields found on the table.</param>
    procedure DimensionCodeFields(TableNo: Integer; var FieldNames: List of [Text])
    var
        RecRef: RecordRef;
        FieldRef: FieldRef;
        Index: Integer;
        Number: Integer;
    begin
        RecRef.Open(TableNo);
        for Index := 1 to RecRef.FieldCount() do begin
            FieldRef := RecRef.FieldIndex(Index);
            for Number := 1 to 8 do
                if (FieldRef.Name() = StrSubstNo('Global Dimension %1 Code', Number)) or (FieldRef.Name() = StrSubstNo('Shortcut Dimension %1 Code', Number)) then
                    FieldNames.Add(FieldRef.Name());
        end;
        RecRef.Close();
    end;

    [TryFunction]
    local procedure TryOpen(TableNo: Integer)
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(TableNo);
        RecRef.Close();
    end;

    local procedure TableExists(TableNo: Integer): Boolean
    begin
        exit(TryOpen(TableNo));
    end;
}
