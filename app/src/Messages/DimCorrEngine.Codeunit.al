namespace Origo.Bifrost.Dimensions;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.Dimension.Correction;
using System.Security.Encryption;

/// <summary>
/// Computes what a dimension correction would do without writing business data: resolves the selection (explicit keys or a
/// document with its lines and ledger entries), applies the cascade rule, builds the new dimension set of every row, validates
/// it and returns the rows, totals and the preview token. The only rows it may create are Dimension Set records, which are not business data.
/// </summary>
codeunit 10076501 "Dim Corr. Engine ori"
{
    Access = Internal;
    Permissions = tabledata Dimension = r,
                  tabledata "Dimension Value" = r,
                  tabledata "Default Dimension" = r,
                  tabledata "Dimension Set Entry" = ri,
                  tabledata "Dimension Set Tree Node" = rim,
                  tabledata "Dimension Combination" = r,
                  tabledata "Dimension Value Combination" = r,
                  tabledata "Dim Correction Blocked Setup" = r,
                  tabledata "Dim. Corr. Blocked Dim. ori" = r;

    var
        Registry: Codeunit "Dim Target Registry ori";
        DimensionManagement: Codeunit DimensionManagement;
        ChangeCodes: List of [Text];
        ChangeActions: List of [Text];
        ChangeValues: List of [Text];
        ChangeFailures: JsonArray;
        Rows: JsonArray;
        RowIds: Dictionary of [Text, Boolean];
        TotalNames: List of [Text];
        TotalRows: Dictionary of [Text, Integer];
        TotalOk: Dictionary of [Text, Integer];
        TotalSkipped: Dictionary of [Text, Integer];
        TotalRefused: Dictionary of [Text, Integer];
        HashInput: TextBuilder;
        HeaderSets: List of [Integer];
        MaxRows: Integer;
        TooManyRows: Boolean;
        OwnDimensionsTok: Label 'own dimensions', Locked = true;
        UnchangedTok: Label 'unchanged', Locked = true;
        RuleDimensionExistsTok: Label 'DimensionExists', Locked = true;
        RuleDimensionBlockedTok: Label 'DimensionBlocked', Locked = true;
        RuleValueExistsTok: Label 'DimensionValueExists', Locked = true;
        RuleValueBlockedTok: Label 'DimensionValueBlocked', Locked = true;
        RuleValueTypeTok: Label 'DimensionValueType', Locked = true;
        RuleCombinationTok: Label 'DimensionCombination', Locked = true;
        RuleValuePostingTok: Label 'ValuePosting', Locked = true;
        DimensionUnknownLbl: Label 'Dimension code %1 does not exist.', Comment = '%1 = dimension code; is-IS=Víddarkóðinn %1 er ekki til.';
        DimensionUnknownNextLbl: Label 'Use a code from the Dimensions list.', Comment = 'is-IS=Notaðu kóða úr víddalistanum.';
        DimensionBlockedLbl: Label 'Dimension %1 is blocked.', Comment = '%1 = dimension code; is-IS=Víddin %1 er læst.';
        DimensionBlockedNextLbl: Label 'Unblock the dimension, or leave it out of the changes.', Comment = 'is-IS=Opnaðu víddina eða slepptu henni úr breytingunum.';
        CorrectionBlockedLbl: Label 'Dimension %1 is on the dimension correction blocked list (%2).', Comment = '%1 = dimension code, %2 = bifrost or microsoft; is-IS=Víddin %1 er á læstum lista víddaleiðréttinga (%2).';
        CorrectionBlockedNextLbl: Label 'Remove the dimension from the blocked list with Dimensions.Setup.Set (Bifrost list) or in Microsoft''s Dimension Correction setup, or leave it out of the changes.', Comment = 'is-IS=Fjarlægðu víddina af læsta listanum með Dimensions.Setup.Set (Bifröst-listi) eða í uppsetningu Microsoft víddaleiðréttinga, eða slepptu henni úr breytingunum.';
        ValueUnknownLbl: Label 'Value %2 does not exist for dimension %1.', Comment = '%1 = dimension code, %2 = value; is-IS=Gildið %2 er ekki til fyrir víddina %1.';
        ValueUnknownNextLbl: Label 'Use a value code from the dimension value list of that dimension.', Comment = 'is-IS=Notaðu gildiskóða úr víddargildum þeirrar víddar.';
        ValueBlockedLbl: Label 'Value %2 of dimension %1 is blocked.', Comment = '%1 = dimension code, %2 = value; is-IS=Gildið %2 í víddinni %1 er læst.';
        ValueBlockedNextLbl: Label 'Unblock the dimension value, or use another value.', Comment = 'is-IS=Opnaðu víddargildið eða notaðu annað gildi.';
        ValueTypeLbl: Label 'Value %2 of dimension %1 is not a standard value and cannot be posted to.', Comment = '%1 = dimension code, %2 = value; is-IS=Gildið %2 í víddinni %1 er ekki venjulegt gildi og ekki hægt að bóka á það.';
        ValueTypeNextLbl: Label 'Use a dimension value of type Standard.', Comment = 'is-IS=Notaðu víddargildi af gerðinni Venjulegt.';
        CombinationLbl: Label 'The new dimension set breaks the dimension combination rules: %1', Comment = '%1 = the combination error; is-IS=Nýja víddarsettið brýtur reglur um víddasamsetningar: %1';
        CombinationNextLbl: Label 'Change the dimension values so the combination is allowed, or change the rules under Dimension Combinations.', Comment = 'is-IS=Breyttu víddargildunum þannig að samsetningin sé leyfð, eða breyttu reglunum í víddasamsetningum.';
        MandatoryLbl: Label 'Dimension %1 must have a value (Code Mandatory) for %2.', Comment = '%1 = dimension code, %2 = source no.; is-IS=Víddin %1 verður að hafa gildi (Kóði skylda) fyrir %2.';
        SameCodeLbl: Label 'Dimension %1 must have the value %3 (Same Code) for %2.', Comment = '%1 = dimension code, %2 = source no., %3 = required value; is-IS=Víddin %1 verður að hafa gildið %3 (Sami kóði) fyrir %2.';
        NoCodeLbl: Label 'Dimension %1 must not have a value (No Code) for %2.', Comment = '%1 = dimension code, %2 = source no.; is-IS=Víddin %1 má ekki hafa gildi (Enginn kóði) fyrir %2.';
        ValuePostingNextLbl: Label 'Follow the default dimension Value Posting rule of the account or source, or change that rule.', Comment = 'is-IS=Fylgdu gildisbókunarreglu sjálfgefinnar víddar reikningsins eða uppruna, eða breyttu reglunni.';

    /// <summary>Computes the preview of a correction.</summary>
    /// <param name="Selection">Validated selection items: {target, entryNos} and/or {documentNo, target}.</param>
    /// <param name="Changes">Validated changes: {code, action, value}.</param>
    /// <param name="MaxRowCount">Largest number of rows the preview may return.</param>
    /// <param name="Result">Receives rowCount, totals, rows, previewToken and expiresAt.</param>
    /// <returns>False when the selection has more rows than MaxRowCount.</returns>
    procedure Preview(Selection: JsonArray; Changes: JsonArray; MaxRowCount: Integer; var Result: JsonObject): Boolean
    var
        Item: JsonToken;
        Text: Text;
    begin
        MaxRows := MaxRowCount;
        Selection.WriteTo(Text);
        HashInput.Append(Text);
        Changes.WriteTo(Text);
        HashInput.Append(Text);
        ReadChanges(Changes);
        CheckChanges();
        foreach Item in Selection do
            if not TooManyRows then
                ProcessSelection(Item.AsObject());
        if TooManyRows then
            exit(false);
        BuildResult(Result);
        exit(true);
    end;

    local procedure ReadChanges(Changes: JsonArray)
    var
        Item: JsonToken;
        Change: JsonObject;
    begin
        foreach Item in Changes do begin
            Change := Item.AsObject();
            ChangeCodes.Add(Change.GetText('code'));
            ChangeActions.Add(Change.GetText('action'));
            ChangeValues.Add(Change.GetText('value'));
        end;
    end;

    local procedure CheckChanges()
    var
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
        BlockedDim: Record "Dim. Corr. Blocked Dim. ori";
        MicrosoftBlocked: Record "Dim Correction Blocked Setup";
        Index: Integer;
        DimensionCode: Text;
        ValueCode: Text;
    begin
        for Index := 1 to ChangeCodes.Count() do begin
            DimensionCode := ChangeCodes.Get(Index);
            ValueCode := ChangeValues.Get(Index);
            if (StrLen(DimensionCode) > MaxStrLen(Dimension.Code)) or not Dimension.Get(CopyStr(DimensionCode, 1, MaxStrLen(Dimension.Code))) then
                AddChangeFailure(RuleDimensionExistsTok, StrSubstNo(DimensionUnknownLbl, DimensionCode), DimensionUnknownNextLbl)
            else begin
                ChangeCodes.Set(Index, Dimension.Code);
                if Dimension.Blocked then
                    AddChangeFailure(RuleDimensionBlockedTok, StrSubstNo(DimensionBlockedLbl, Dimension.Code), DimensionBlockedNextLbl);
                if BlockedDim.Get(Dimension.Code) then
                    AddChangeFailure(RuleDimensionBlockedTok, StrSubstNo(CorrectionBlockedLbl, Dimension.Code, 'bifrost'), CorrectionBlockedNextLbl);
                if MicrosoftBlocked.Get(Dimension.Code) then
                    AddChangeFailure(RuleDimensionBlockedTok, StrSubstNo(CorrectionBlockedLbl, Dimension.Code, 'microsoft'), CorrectionBlockedNextLbl);
                if ChangeActions.Get(Index) = 'set' then
                    if (StrLen(ValueCode) > MaxStrLen(DimensionValue.Code)) or not DimensionValue.Get(Dimension.Code, CopyStr(ValueCode, 1, MaxStrLen(DimensionValue.Code))) then
                        AddChangeFailure(RuleValueExistsTok, StrSubstNo(ValueUnknownLbl, Dimension.Code, ValueCode), ValueUnknownNextLbl)
                    else begin
                        ChangeValues.Set(Index, DimensionValue.Code);
                        if DimensionValue.Blocked then
                            AddChangeFailure(RuleValueBlockedTok, StrSubstNo(ValueBlockedLbl, Dimension.Code, DimensionValue.Code), ValueBlockedNextLbl);
                        if DimensionValue."Dimension Value Type" <> DimensionValue."Dimension Value Type"::Standard then
                            AddChangeFailure(RuleValueTypeTok, StrSubstNo(ValueTypeLbl, Dimension.Code, DimensionValue.Code), ValueTypeNextLbl);
                    end;
            end;
        end;
    end;

    local procedure AddChangeFailure(Rule: Text; Message: Text; NextStep: Text)
    var
        Failure: JsonObject;
    begin
        Failure.Add('rule', Rule);
        Failure.Add('message', Message);
        Failure.Add('nextStep', NextStep);
        ChangeFailures.Add(Failure);
    end;

    local procedure ProcessSelection(Item: JsonObject)
    var
        Descriptor: JsonObject;
        Target: Enum "Dim. Correction Target ori";
        Targets: List of [Integer];
        Ordinal: Integer;
        TargetName: Text;
        DocumentNo: Text;
        Keys: JsonArray;
        KeyToken: JsonToken;
        HasTarget: Boolean;
    begin
        if Item.Contains('target') then
            TargetName := Item.GetText('target');
        if Item.Contains('documentNo') then
            DocumentNo := Item.GetText('documentNo');
        HasTarget := TargetName <> '';
        if HasTarget then
            Registry.FindTarget(TargetName, Target);
        if Item.Contains('entryNos') then begin
            Descriptor := Describe(Target);
            Keys := Item.GetArray('entryNos');
            foreach KeyToken in Keys do
                if not TooManyRows then
                    ProcessKey(Descriptor, KeyToken.AsValue().AsText());
            exit;
        end;
        Clear(HeaderSets);
        Registry.ListAvailable(Targets);
        foreach Ordinal in Targets do begin
            Target := Enum::"Dim. Correction Target ori".FromInteger(Ordinal);
            Descriptor := Describe(Target);
            if Descriptor.GetText('kind') = 'Document' then
                if (not HasTarget) or (UpperCase(TargetName) = UpperCase(Descriptor.GetText('name'))) then
                    if not TooManyRows then
                        ProcessDocumentHeaders(Descriptor, DocumentNo);
        end;
        foreach Ordinal in Targets do begin
            Target := Enum::"Dim. Correction Target ori".FromInteger(Ordinal);
            Descriptor := Describe(Target);
            if Descriptor.GetText('kind') = 'Ledger' then
                if (not HasTarget) or (UpperCase(TargetName) = UpperCase(Descriptor.GetText('name'))) or (GetKind(TargetName) = 'Document') then
                    if not TooManyRows then
                        ProcessDocumentLedger(Descriptor, DocumentNo);
        end;
    end;

    local procedure GetKind(TargetName: Text): Text
    var
        Target: Enum "Dim. Correction Target ori";
    begin
        if not Registry.FindTarget(TargetName, Target) then
            exit('');
        exit(Describe(Target).GetText('kind'));
    end;

    local procedure Describe(Target: Enum "Dim. Correction Target ori") Descriptor: JsonObject
    var
        Implementation: Interface "Dim. Correction Target ori";
    begin
        Implementation := Target;
        Descriptor := Implementation.Describe(Target);
    end;

    local procedure ProcessKey(Descriptor: JsonObject; KeyText: Text)
    var
        RecRef: RecordRef;
        Fields: Dictionary of [Text, Integer];
        FieldRef: FieldRef;
        IntegerKey: Integer;
    begin
        RecRef.Open(Descriptor.GetInteger('tableNo'));
        MapFields(RecRef, Fields);
        FieldRef := RecRef.Field(Fields.Get(Descriptor.GetText('keyField')));
        if FieldRef.Type() in [FieldType::Integer, FieldType::BigInteger] then begin
            if not Evaluate(IntegerKey, KeyText) then
                exit;
            FieldRef.SetRange(IntegerKey);
        end else begin
            if StrLen(KeyText) > FieldRef.Length() then
                exit;
            FieldRef.SetRange(KeyText);
        end;
        FilterStatus(RecRef, Fields, Descriptor);
        if RecRef.FindFirst() then begin
            AddRow(RecRef, Fields, Descriptor, false, '');
            if Descriptor.GetText('kind') = 'Document' then
                CascadeLines(RecRef, Fields, Descriptor);
        end;
        RecRef.Close();
    end;

    local procedure ProcessDocumentHeaders(Descriptor: JsonObject; DocumentNo: Text)
    var
        RecRef: RecordRef;
        Fields: Dictionary of [Text, Integer];
        FieldRef: FieldRef;
    begin
        RecRef.Open(Descriptor.GetInteger('tableNo'));
        MapFields(RecRef, Fields);
        FieldRef := RecRef.Field(Fields.Get(Descriptor.GetText('documentNoField')));
        if StrLen(DocumentNo) <= FieldRef.Length() then begin
            FieldRef.SetRange(DocumentNo);
            FilterStatus(RecRef, Fields, Descriptor);
            if RecRef.FindSet() then
                repeat
                    if not TooManyRows then begin
                        AddRow(RecRef, Fields, Descriptor, false, '');
                        CascadeLines(RecRef, Fields, Descriptor);
                    end;
                until (RecRef.Next() = 0) or TooManyRows;
        end;
        RecRef.Close();
    end;

    local procedure ProcessDocumentLedger(Descriptor: JsonObject; DocumentNo: Text)
    var
        RecRef: RecordRef;
        Fields: Dictionary of [Text, Integer];
        FieldRef: FieldRef;
        SetId: Integer;
    begin
        RecRef.Open(Descriptor.GetInteger('tableNo'));
        MapFields(RecRef, Fields);
        FieldRef := RecRef.Field(Fields.Get(Descriptor.GetText('documentNoField')));
        if StrLen(DocumentNo) <= FieldRef.Length() then begin
            FieldRef.SetRange(DocumentNo);
            if RecRef.FindSet() then
                repeat
                    SetId := SetIdOf(RecRef, Fields, Descriptor);
                    if (HeaderSets.Count() = 0) or HeaderSets.Contains(SetId) then
                        AddRow(RecRef, Fields, Descriptor, false, '')
                    else
                        AddRow(RecRef, Fields, Descriptor, false, OwnDimensionsTok);
                until (RecRef.Next() = 0) or TooManyRows;
        end;
        RecRef.Close();
    end;

    local procedure CascadeLines(var HeaderRef: RecordRef; HeaderFields: Dictionary of [Text, Integer]; Descriptor: JsonObject)
    var
        LineRef: RecordRef;
        LineFields: Dictionary of [Text, Integer];
        HeaderSet: Integer;
        LineSet: Integer;
    begin
        HeaderSet := SetIdOf(HeaderRef, HeaderFields, Descriptor);
        if not HeaderSets.Contains(HeaderSet) then
            HeaderSets.Add(HeaderSet);
        LineRef.Open(Descriptor.GetInteger('lineTableNo'));
        MapFields(LineRef, LineFields);
        if not (LineFields.ContainsKey(Descriptor.GetText('lineLinkField')) and LineFields.ContainsKey(Descriptor.GetText('dimensionSetIdField'))) then begin
            LineRef.Close();
            exit;
        end;
        LineRef.Field(LineFields.Get(Descriptor.GetText('lineLinkField'))).SetRange(HeaderRef.Field(HeaderFields.Get(Descriptor.GetText('keyField'))).Value());
        if Descriptor.Contains('statusField') then
            if LineFields.ContainsKey(Descriptor.GetText('statusField')) then
                LineRef.Field(LineFields.Get(Descriptor.GetText('statusField'))).SetRange(Descriptor.GetInteger('statusValue'));
        if LineRef.FindSet() then
            repeat
                LineSet := SetIdOf(LineRef, LineFields, Descriptor);
                if LineSet = HeaderSet then
                    AddRow(LineRef, LineFields, Descriptor, true, '')
                else
                    AddRow(LineRef, LineFields, Descriptor, true, OwnDimensionsTok);
            until (LineRef.Next() = 0) or TooManyRows;
        LineRef.Close();
    end;

    local procedure FilterStatus(var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; Descriptor: JsonObject)
    begin
        if not Descriptor.Contains('statusField') then
            exit;
        if Fields.ContainsKey(Descriptor.GetText('statusField')) then
            RecRef.Field(Fields.Get(Descriptor.GetText('statusField'))).SetRange(Descriptor.GetInteger('statusValue'));
    end;

    local procedure SetIdOf(var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; Descriptor: JsonObject) SetId: Integer
    begin
        Evaluate(SetId, Format(RecRef.Field(Fields.Get(Descriptor.GetText('dimensionSetIdField'))).Value()));
    end;

    local procedure AddRow(var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; Descriptor: JsonObject; IsLine: Boolean; SkipReason: Text)
    var
        Row: JsonObject;
        KeyValues: JsonObject;
        TableName: Text;
        KeyText: Text;
        RowId: Text;
        OldSetId: Integer;
        Status: Text;
    begin
        TableName := Descriptor.GetText('name');
        if IsLine then
            TableName += ' Line';
        KeyValues := KeyObject(RecRef);
        KeyValues.WriteTo(KeyText);
        RowId := TableName + '|' + KeyText;
        if RowIds.ContainsKey(RowId) then
            exit;
        if Rows.Count() >= MaxRows then begin
            TooManyRows := true;
            exit;
        end;
        RowIds.Add(RowId, true);
        OldSetId := SetIdOf(RecRef, Fields, Descriptor);
        HashInput.Append(RowId + '|' + Format(OldSetId) + ';');
        Row.Add('table', TableName);
        Row.Add('key', KeyValues);
        Row.Add('dimensionSetId', OldSetId);
        Row.Add('oldDimensions', SetToArray(OldSetId));
        if SkipReason <> '' then begin
            Status := 'skipped';
            Row.Add('status', Status);
            Row.Add('reason', SkipReason);
        end else
            Status := EvaluateRow(Row, RecRef, Fields, Descriptor, IsLine, OldSetId, TableName, KeyValues);
        Rows.Add(Row);
        Bump(TableName, Status);
    end;

    local procedure EvaluateRow(var Row: JsonObject; var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; Descriptor: JsonObject; IsLine: Boolean; OldSetId: Integer; TableName: Text; KeyValues: JsonObject) Status: Text
    var
        TempNew: Record "Dimension Set Entry" temporary;
        Failures: JsonArray;
        Failure: JsonToken;
        Detail: JsonObject;
        NewSetId: Integer;
    begin
        if ChangeFailures.Count() > 0 then begin
            foreach Failure in ChangeFailures do
                Failures.Add(WithRow(Failure.AsObject(), TableName, KeyValues));
            Row.Add('status', 'refused');
            Row.Add('reason', Failures.GetObject(0).GetText('message'));
            Row.Add('failures', Failures);
            exit('refused');
        end;
        LoadSet(OldSetId, TempNew);
        ApplyChanges(TempNew);
        NewSetId := DimensionManagement.GetDimensionSetID(TempNew);
        if NewSetId = OldSetId then begin
            Row.Add('status', 'skipped');
            Row.Add('reason', UnchangedTok);
            exit('skipped');
        end;
        Row.Add('newDimensionSetId', NewSetId);
        Row.Add('newDimensions', SetToArray(NewSetId));
        CheckRules(NewSetId, TempNew, RecRef, Fields, Descriptor, IsLine, TableName, KeyValues, Failures);
        if Failures.Count() = 0 then begin
            Row.Add('status', 'ok');
            exit('ok');
        end;
        Row.Add('status', 'refused');
        Failures.Get(0, Failure);
        Detail := Failure.AsObject();
        Row.Add('reason', Detail.GetText('message'));
        Row.Add('failures', Failures);
        exit('refused');
    end;

    local procedure WithRow(Source: JsonObject; TableName: Text; KeyValues: JsonObject) Failure: JsonObject
    var
        Copy: JsonObject;
        KeyText: Text;
    begin
        Failure.Add('table', TableName);
        Failure.Add('key', KeyValues);
        Failure.Add('rule', Source.GetText('rule'));
        Failure.Add('message', Source.GetText('message'));
        Failure.Add('nextStep', Source.GetText('nextStep'));
        Clear(Copy);
        Clear(KeyText);
    end;

    local procedure LoadSet(SetId: Integer; var TempNew: Record "Dimension Set Entry" temporary)
    var
        SetEntry: Record "Dimension Set Entry";
    begin
        SetEntry.SetRange("Dimension Set ID", SetId);
        if SetEntry.FindSet() then
            repeat
                TempNew := SetEntry;
                TempNew."Dimension Set ID" := 0;
                TempNew.Insert();
            until SetEntry.Next() = 0;
    end;

    local procedure ApplyChanges(var TempNew: Record "Dimension Set Entry" temporary)
    var
        DimensionValue: Record "Dimension Value";
        Index: Integer;
        DimensionCode: Code[20];
    begin
        for Index := 1 to ChangeCodes.Count() do begin
            DimensionCode := CopyStr(ChangeCodes.Get(Index), 1, MaxStrLen(DimensionCode));
            if ChangeActions.Get(Index) = 'remove' then begin
                if TempNew.Get(0, DimensionCode) then
                    TempNew.Delete();
            end else begin
                DimensionValue.Get(DimensionCode, CopyStr(ChangeValues.Get(Index), 1, MaxStrLen(DimensionValue.Code)));
                if TempNew.Get(0, DimensionCode) then begin
                    TempNew."Dimension Value Code" := DimensionValue.Code;
                    TempNew."Dimension Value ID" := DimensionValue."Dimension Value ID";
                    TempNew.Modify();
                end else begin
                    TempNew.Init();
                    TempNew."Dimension Set ID" := 0;
                    TempNew."Dimension Code" := DimensionCode;
                    TempNew."Dimension Value Code" := DimensionValue.Code;
                    TempNew."Dimension Value ID" := DimensionValue."Dimension Value ID";
                    TempNew.Insert();
                end;
            end;
        end;
    end;

    local procedure CheckRules(NewSetId: Integer; var TempNew: Record "Dimension Set Entry" temporary; var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; Descriptor: JsonObject; IsLine: Boolean; TableName: Text; KeyValues: JsonObject; var Failures: JsonArray)
    var
        DefaultDimension: Record "Default Dimension";
        Failure: JsonObject;
        DefaultTableNo: Integer;
        SourceField: Text;
        SourceNo: Text;
        Index: Integer;
        DimensionCode: Code[20];
    begin
        if not DimensionManagement.CheckDimIDComb(NewSetId) then begin
            Clear(Failure);
            Failure.Add('rule', RuleCombinationTok);
            Failure.Add('message', StrSubstNo(CombinationLbl, DimensionManagement.GetDimCombErr()));
            Failure.Add('nextStep', CombinationNextLbl);
            Failures.Add(WithRow(Failure, TableName, KeyValues));
        end;
        if IsLine then
            exit;
        DefaultTableNo := DefaultDimensionTableNo(Descriptor.GetText('name'));
        if DefaultTableNo = 0 then
            exit;
        SourceField := Descriptor.GetText('sourceNoField');
        if Descriptor.GetText('name') = 'G/L Entry' then
            SourceField := 'G/L Account No.';
        if not Fields.ContainsKey(SourceField) then
            exit;
        SourceNo := Format(RecRef.Field(Fields.Get(SourceField)).Value());
        if SourceNo = '' then
            exit;
        for Index := 1 to ChangeCodes.Count() do begin
            DimensionCode := CopyStr(ChangeCodes.Get(Index), 1, MaxStrLen(DimensionCode));
            if DefaultDimension.Get(DefaultTableNo, CopyStr(SourceNo, 1, MaxStrLen(DefaultDimension."No.")), DimensionCode) then
                CheckValuePosting(DefaultDimension, TempNew, SourceNo, TableName, KeyValues, Failures);
        end;
    end;

    local procedure CheckValuePosting(DefaultDimension: Record "Default Dimension"; var TempNew: Record "Dimension Set Entry" temporary; SourceNo: Text; TableName: Text; KeyValues: JsonObject; var Failures: JsonArray)
    var
        Failure: JsonObject;
        HasValue: Boolean;
        Message: Text;
    begin
        HasValue := TempNew.Get(0, DefaultDimension."Dimension Code");
        case DefaultDimension."Value Posting" of
            DefaultDimension."Value Posting"::"Code Mandatory":
                if not HasValue then
                    Message := StrSubstNo(MandatoryLbl, DefaultDimension."Dimension Code", SourceNo);
            DefaultDimension."Value Posting"::"Same Code":
                if (not HasValue) or (TempNew."Dimension Value Code" <> DefaultDimension."Dimension Value Code") then
                    Message := StrSubstNo(SameCodeLbl, DefaultDimension."Dimension Code", SourceNo, DefaultDimension."Dimension Value Code");
            DefaultDimension."Value Posting"::"No Code":
                if HasValue then
                    Message := StrSubstNo(NoCodeLbl, DefaultDimension."Dimension Code", SourceNo);
        end;
        if Message = '' then
            exit;
        Failure.Add('rule', RuleValuePostingTok);
        Failure.Add('message', Message);
        Failure.Add('nextStep', ValuePostingNextLbl);
        Failures.Add(WithRow(Failure, TableName, KeyValues));
    end;

    local procedure DefaultDimensionTableNo(TargetName: Text): Integer
    begin
        case TargetName of
            'G/L Entry':
                exit(15);
            'Cust. Ledger Entry', 'Service Ledger Entry', 'Warranty Ledger Entry', 'Sales Shipment', 'Sales Invoice', 'Sales Cr.Memo', 'Return Receipt',
            'Service Shipment', 'Service Invoice', 'Service Cr.Memo', 'Issued Reminder', 'Issued Fin. Charge Memo':
                exit(18);
            'Vendor Ledger Entry', 'Purch. Rcpt.', 'Purch. Inv.', 'Purch. Cr. Memo', 'Return Shipment':
                exit(23);
            'Bank Account Ledger Entry':
                exit(270);
            'Item Ledger Entry', 'Value Entry', 'Phys. Inventory Ledger Entry', 'Posted Assembly Header':
                exit(27);
            'FA Ledger Entry', 'Maintenance Ledger Entry', 'Ins. Coverage Ledger Entry':
                exit(5600);
            'Res. Ledger Entry':
                exit(156);
            'Job Ledger Entry', 'Job WIP Entry', 'Job WIP G/L Entry':
                exit(167);
        end;
        exit(0);
    end;

    local procedure SetToArray(SetId: Integer) Result: JsonArray
    var
        SetEntry: Record "Dimension Set Entry";
        Entry: JsonObject;
    begin
        SetEntry.SetRange("Dimension Set ID", SetId);
        if SetEntry.FindSet() then
            repeat
                Clear(Entry);
                Entry.Add('code', SetEntry."Dimension Code");
                Entry.Add('value', SetEntry."Dimension Value Code");
                Result.Add(Entry);
            until SetEntry.Next() = 0;
    end;

    local procedure Bump(TableName: Text; Status: Text)
    begin
        if not TotalRows.ContainsKey(TableName) then begin
            TotalNames.Add(TableName);
            TotalRows.Add(TableName, 0);
            TotalOk.Add(TableName, 0);
            TotalSkipped.Add(TableName, 0);
            TotalRefused.Add(TableName, 0);
        end;
        TotalRows.Set(TableName, TotalRows.Get(TableName) + 1);
        case Status of
            'ok':
                TotalOk.Set(TableName, TotalOk.Get(TableName) + 1);
            'skipped':
                TotalSkipped.Set(TableName, TotalSkipped.Get(TableName) + 1);
            'refused':
                TotalRefused.Set(TableName, TotalRefused.Get(TableName) + 1);
        end;
    end;

    local procedure BuildResult(var Result: JsonObject)
    var
        CryptographyManagement: Codeunit "Cryptography Management";
        Totals: JsonArray;
        Total: JsonObject;
        TableName: Text;
        OkCount: Integer;
        SkippedCount: Integer;
        RefusedCount: Integer;
    begin
        foreach TableName in TotalNames do begin
            Clear(Total);
            Total.Add('table', TableName);
            Total.Add('rows', TotalRows.Get(TableName));
            Total.Add('ok', TotalOk.Get(TableName));
            Total.Add('skipped', TotalSkipped.Get(TableName));
            Total.Add('refused', TotalRefused.Get(TableName));
            Totals.Add(Total);
            OkCount += TotalOk.Get(TableName);
            SkippedCount += TotalSkipped.Get(TableName);
            RefusedCount += TotalRefused.Get(TableName);
        end;
        Result.Add('rowCount', Rows.Count());
        Result.Add('okCount', OkCount);
        Result.Add('skippedCount', SkippedCount);
        Result.Add('refusedCount', RefusedCount);
        Result.Add('totals', Totals);
        Result.Add('rows', Rows);
        Result.Add('previewToken', CryptographyManagement.GenerateHash(HashInput.ToText(), 2));
        Result.Add('expiresAt', Format(CurrentDateTime() + 1800000, 0, 9));
    end;

    local procedure KeyObject(var RecRef: RecordRef) KeyValues: JsonObject
    var
        KeyRef: KeyRef;
        FieldRef: FieldRef;
        Index: Integer;
        IntegerValue: Integer;
    begin
        KeyRef := RecRef.KeyIndex(1);
        for Index := 1 to KeyRef.FieldCount() do begin
            FieldRef := KeyRef.FieldIndex(Index);
            if (FieldRef.Type() in [FieldType::Integer]) and Evaluate(IntegerValue, Format(FieldRef.Value())) then
                KeyValues.Add(FieldRef.Name(), IntegerValue)
            else
                KeyValues.Add(FieldRef.Name(), Format(FieldRef.Value()));
        end;
    end;

    local procedure MapFields(var RecRef: RecordRef; var Fields: Dictionary of [Text, Integer])
    var
        Index: Integer;
    begin
        for Index := 1 to RecRef.FieldCount() do
            Fields.Add(RecRef.FieldIndex(Index).Name(), RecRef.FieldIndex(Index).Number());
    end;
}
