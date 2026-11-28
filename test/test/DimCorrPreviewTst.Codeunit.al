namespace Origo.Bifrost.Dimensions.Test;

using Origo.Bifrost;
using Origo.Bifrost.Dimensions;
using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Sales.History;
using Microsoft.Sales.Receivables;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests Dimensions.Correction.Preview: the cascade rule, every validation rule, set and remove, the reason requirement,
/// the preview token, the row limit and that no ledger or document row changes. Each test seeds its own XDIMT data.
/// </summary>
codeunit 98330 "Dim Corr Preview Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    Permissions = tabledata "G/L Entry" = RIMD,
                  tabledata "Cust. Ledger Entry" = RIMD,
                  tabledata "Sales Invoice Header" = RIMD,
                  tabledata "Sales Invoice Line" = RIMD,
                  tabledata Dimension = RIMD,
                  tabledata "Dimension Value" = RIMD,
                  tabledata "Dimension Set Entry" = RIMD,
                  tabledata "Dimension Combination" = RIMD,
                  tabledata "Default Dimension" = RIMD;

    var
        Assert: Codeunit "Library Assert";
        DocumentTok: Label 'XDIMT-001', Locked = true;
        DimensionTok: Label 'XDIMT', Locked = true;
        OtherDimensionTok: Label 'XDIMU', Locked = true;
        ValueATok: Label 'XVA', Locked = true;
        ValueBTok: Label 'XVB', Locked = true;
        ValueHeadingTok: Label 'XVH', Locked = true;
        OtherValueTok: Label 'XUA', Locked = true;
        CustomerTok: Label 'XDIMT-C', Locked = true;

    /// <summary>AC2/AC7: header lines with the header's set cascade; a line with its own dimensions is skipped.</summary>
    [Test]
    procedure Scenario_AC02_CascadeSkipsLineWithOwnDimensions()
    var
        Reply: JsonObject;
    begin
        // [GIVEN] An invoice with XVA, a line with XVA and a line with its own XVB
        Initialize(false);
        SeedSalesInvoice(DocumentTok, ValueATok, ValueATok, ValueBTok);
        // [WHEN] Previewing XDIMT=XVB... on the header selection
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"Sales Invoice","entryNos":["%1"]}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', DocumentTok, DimensionTok, ValueBTok));
        // [THEN] Header and line 10000 are ok, line 20000 is skipped as own dimensions
        AssertSuccess(Reply);
        Assert.AreEqual(3, Reply.GetInteger('rowCount'), 'Header and two lines');
        Assert.AreEqual('ok', RowStatus(Reply, 'Sales Invoice', 'No.', DocumentTok), 'Header');
        Assert.AreEqual('ok', RowStatus(Reply, 'Sales Invoice Line', 'Line No.', '10000'), 'Line with the header set');
        Assert.AreEqual('skipped', RowStatus(Reply, 'Sales Invoice Line', 'Line No.', '20000'), 'Line with own dimensions');
        Assert.AreEqual('own dimensions', RowReason(Reply, 'Sales Invoice Line', 'Line No.', '20000'), 'Reason');
        Assert.AreEqual(1, Reply.GetInteger('skippedCount'), 'Skipped total');
    end;

    /// <summary>AC1/AC2: a document selection takes the header, lines and ledger entries; ledger entries follow the header's set.</summary>
    [Test]
    procedure Scenario_AC02_DocumentSelectionIncludesLedgerEntries()
    var
        Reply: JsonObject;
        FollowEntryNo: Integer;
        OwnEntryNo: Integer;
    begin
        // [GIVEN] An invoice with XVA and two G/L entries of the same document, one with XVA and one with XVB
        Initialize(false);
        SeedSalesInvoice(DocumentTok, ValueATok, ValueATok, ValueATok);
        FollowEntryNo := SeedGLEntry(DocumentTok, ValueATok);
        OwnEntryNo := SeedGLEntry(DocumentTok, ValueBTok);
        // [WHEN] Previewing a removal on the document
        Reply := Invoke(StrSubstNo('{"selection":[{"documentNo":"%1"}],"changes":[{"code":"%2","action":"remove"}]}', DocumentTok, DimensionTok));
        // [THEN] The entry with the header set is ok, the other is skipped
        AssertSuccess(Reply);
        Assert.AreEqual('ok', RowStatus(Reply, 'G/L Entry', 'Entry No.', Format(FollowEntryNo)), 'Entry with the header set');
        Assert.AreEqual('skipped', RowStatus(Reply, 'G/L Entry', 'Entry No.', Format(OwnEntryNo)), 'Entry with own set');
        Assert.AreEqual('ok', RowStatus(Reply, 'Sales Invoice', 'No.', DocumentTok), 'Header');
    end;

    /// <summary>AC1/AC4: set replaces and adds a value, remove deletes it; the response carries old and new lists and set id.</summary>
    [Test]
    procedure Scenario_AC04_SetAndRemoveShapeTheNewList()
    var
        Reply: JsonObject;
        Row: JsonObject;
        EntryNo: Integer;
    begin
        // [GIVEN] A G/L entry with XDIMT=XVA and XDIMU=XUA
        Initialize(false);
        EntryNo := SeedGLEntryTwo(DocumentTok, ValueATok, OtherValueTok);
        // [WHEN] Setting XDIMT to XVB
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', EntryNo, DimensionTok, ValueBTok));
        // [THEN] The value is replaced and the other dimension kept
        AssertSuccess(Reply);
        Row := Reply.GetArray('rows').GetObject(0);
        Assert.AreEqual('ok', Row.GetText('status'), 'Status');
        Assert.AreEqual(2, Row.GetArray('oldDimensions').Count(), 'Old list');
        Assert.AreEqual(2, Row.GetArray('newDimensions').Count(), 'New list');
        Assert.IsTrue(Row.GetInteger('newDimensionSetId') > 0, 'New set id');
        Assert.AreNotEqual(Row.GetInteger('dimensionSetId'), Row.GetInteger('newDimensionSetId'), 'Set changes');
        Assert.AreEqual(1, Reply.GetArray('totals').Count(), 'Totals per table');
        Assert.AreNotEqual('', Reply.GetText('previewToken'), 'Token');
        Assert.AreNotEqual('', Reply.GetText('expiresAt'), 'Expiry');
        // [WHEN] Removing XDIMT
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"remove"}]}', EntryNo, DimensionTok));
        // [THEN] One dimension is left
        Assert.AreEqual(1, Reply.GetArray('rows').GetObject(0).GetArray('newDimensions').Count(), 'Removed');
        // [WHEN] Setting the value it already has
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', EntryNo, DimensionTok, ValueATok));
        // [THEN] The row is skipped as unchanged
        Assert.AreEqual('skipped', Reply.GetArray('rows').GetObject(0).GetText('status'), 'Unchanged');
        Assert.AreEqual('unchanged', Reply.GetArray('rows').GetObject(0).GetText('reason'), 'Unchanged reason');
    end;

    /// <summary>AC1: reason is required when the setup says so and optional otherwise.</summary>
    [Test]
    procedure Scenario_AC01_ReasonRequiredBySetup()
    var
        Reply: JsonObject;
        EntryNo: Integer;
    begin
        // [GIVEN] A setup that requires a reason
        Initialize(true);
        EntryNo := SeedGLEntry(DocumentTok, ValueATok);
        // [WHEN] Previewing without reason
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"remove"}]}', EntryNo, DimensionTok));
        // [THEN] The call is refused
        AssertRefusal(Reply, 'MissingParameter');
        // [WHEN] Sending a reason
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"remove"}],"reason":"Wrong department"}', EntryNo, DimensionTok));
        // [THEN] The preview succeeds
        AssertSuccess(Reply);
    end;

    /// <summary>AC3/AC7: dimension and value rules refuse the row with table, key, rule and next step.</summary>
    [Test]
    procedure Scenario_AC03_DimensionAndValueRulesRefuse()
    var
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
        Reply: JsonObject;
        Failure: JsonObject;
        EntryNo: Integer;
    begin
        // [GIVEN] A G/L entry
        Initialize(false);
        EntryNo := SeedGLEntry(DocumentTok, ValueATok);
        // [THEN] Unknown dimension, unknown value, blocked dimension, correction-blocked dimension, blocked value and a heading value are all refused
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"XNOPE","action":"set","value":"A"}]}', EntryNo));
        Failure := FirstFailure(Reply);
        Assert.AreEqual('DimensionExists', Failure.GetText('rule'), 'Unknown dimension');
        Assert.AreEqual('G/L Entry', Failure.GetText('table'), 'Failure names the table');
        Assert.IsTrue(Failure.GetObject('key').Contains('Entry No.'), 'Failure names the key');
        Assert.AreNotEqual('', Failure.GetText('nextStep'), 'Next step');
        Assert.AreEqual('refused', Reply.GetArray('rows').GetObject(0).GetText('status'), 'Row refused');
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"set","value":"NOVALUE"}]}', EntryNo, DimensionTok));
        Assert.AreEqual('DimensionValueExists', FirstFailure(Reply).GetText('rule'), 'Unknown value');
        Dimension.Get(DimensionTok);
        Dimension.Blocked := true;
        Dimension.Modify();
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"remove"}]}', EntryNo, DimensionTok));
        Assert.AreEqual('DimensionBlocked', FirstFailure(Reply).GetText('rule'), 'Blocked dimension');
        Dimension.Blocked := false;
        Dimension.Modify();
        SetSetup(false, StrSubstNo('["%1"]', DimensionTok));
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"remove"}]}', EntryNo, DimensionTok));
        Assert.AreEqual('DimensionBlocked', FirstFailure(Reply).GetText('rule'), 'Correction blocked dimension');
        SetSetup(false, '[]');
        DimensionValue.Get(DimensionTok, ValueBTok);
        DimensionValue.Blocked := true;
        DimensionValue.Modify();
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', EntryNo, DimensionTok, ValueBTok));
        Assert.AreEqual('DimensionValueBlocked', FirstFailure(Reply).GetText('rule'), 'Blocked value');
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', EntryNo, DimensionTok, ValueHeadingTok));
        Assert.AreEqual('DimensionValueType', FirstFailure(Reply).GetText('rule'), 'Heading value');
    end;

    /// <summary>AC3: a new set that breaks the combination rules is refused.</summary>
    [Test]
    procedure Scenario_AC03_CombinationRuleRefuses()
    var
        Combination: Record "Dimension Combination";
        Reply: JsonObject;
        EntryNo: Integer;
    begin
        // [GIVEN] An entry with XDIMU=XUA and a blocked combination of XDIMT and XDIMU
        Initialize(false);
        EntryNo := SeedGLEntryTwo(DocumentTok, '', OtherValueTok);
        Combination.Init();
        Combination."Dimension 1 Code" := DimensionTok;
        Combination."Dimension 2 Code" := OtherDimensionTok;
        Combination."Combination Restriction" := Combination."Combination Restriction"::Blocked;
        Combination.Insert();
        // [WHEN] Adding XDIMT
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', EntryNo, DimensionTok, ValueATok));
        // [THEN] The row is refused by the combination rule
        AssertSuccess(Reply);
        Assert.AreEqual('refused', Reply.GetArray('rows').GetObject(0).GetText('status'), 'Refused');
        Assert.AreEqual('DimensionCombination', FirstFailure(Reply).GetText('rule'), 'Rule');
    end;

    /// <summary>AC3: default dimension Value Posting rules (Code Mandatory, Same Code, No Code) are enforced for the source.</summary>
    [Test]
    procedure Scenario_AC03_ValuePostingRulesRefuse()
    var
        DefaultDimension: Record "Default Dimension";
        Reply: JsonObject;
        EntryNo: Integer;
    begin
        // [GIVEN] A customer ledger entry for a customer whose default dimension XDIMT is Code Mandatory
        Initialize(false);
        EntryNo := SeedCustEntry(ValueATok);
        DefaultDimension.Init();
        DefaultDimension."Table ID" := 18;
        DefaultDimension."No." := CustomerTok;
        DefaultDimension."Dimension Code" := DimensionTok;
        DefaultDimension."Value Posting" := DefaultDimension."Value Posting"::"Code Mandatory";
        DefaultDimension.Insert();
        // [THEN] Removing the dimension is refused, replacing it is allowed
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"Cust. Ledger Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"remove"}]}', EntryNo, DimensionTok));
        Assert.AreEqual('ValuePosting', FirstFailure(Reply).GetText('rule'), 'Code Mandatory');
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"Cust. Ledger Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', EntryNo, DimensionTok, ValueBTok));
        Assert.AreEqual('ok', Reply.GetArray('rows').GetObject(0).GetText('status'), 'Replacement allowed');
        // [WHEN] The rule is Same Code with value XVA
        DefaultDimension."Value Posting" := DefaultDimension."Value Posting"::"Same Code";
        DefaultDimension."Dimension Value Code" := ValueATok;
        DefaultDimension.Modify();
        // [THEN] Another value is refused
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"Cust. Ledger Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', EntryNo, DimensionTok, ValueBTok));
        Assert.AreEqual('ValuePosting', FirstFailure(Reply).GetText('rule'), 'Same Code');
        // [WHEN] The rule is No Code
        DefaultDimension."Value Posting" := DefaultDimension."Value Posting"::"No Code";
        DefaultDimension."Dimension Value Code" := '';
        DefaultDimension.Modify();
        // [THEN] Keeping a value is refused and removing it is allowed
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"Cust. Ledger Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', EntryNo, DimensionTok, ValueBTok));
        Assert.AreEqual('ValuePosting', FirstFailure(Reply).GetText('rule'), 'No Code');
        Reply := Invoke(StrSubstNo('{"selection":[{"target":"Cust. Ledger Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"remove"}]}', EntryNo, DimensionTok));
        Assert.AreEqual('ok', Reply.GetArray('rows').GetObject(0).GetText('status'), 'Removal allowed');
    end;

    /// <summary>AC4/AC7: the token is stable for the same input and changes when a row's set changes.</summary>
    [Test]
    procedure Scenario_AC04_TokenChangesWhenRowSetChanges()
    var
        GLEntry: Record "G/L Entry";
        Request: Text;
        First: Text;
        EntryNo: Integer;
    begin
        // [GIVEN] A preview of one entry
        Initialize(false);
        EntryNo := SeedGLEntry(DocumentTok, ValueATok);
        Request := StrSubstNo('{"selection":[{"target":"G/L Entry","entryNos":[%1]}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', EntryNo, DimensionTok, ValueBTok);
        First := Invoke(Request).GetText('previewToken');
        // [THEN] The same input gives the same token
        Assert.AreEqual(First, Invoke(Request).GetText('previewToken'), 'Stable token');
        // [WHEN] The row's set changes
        GLEntry.Get(EntryNo);
        GLEntry."Dimension Set ID" := DimensionSetFor(DimensionTok, ValueBTok, '', '');
        GLEntry.Modify(false);
        // [THEN] The token differs
        Assert.AreNotEqual(First, Invoke(Request).GetText('previewToken'), 'Token follows the set');
    end;

    /// <summary>AC5: nothing is written to ledger or document rows and too large selections are refused.</summary>
    [Test]
    procedure Scenario_AC05_NothingWrittenAndRowLimit()
    var
        GLEntry: Record "G/L Entry";
        Reply: JsonObject;
        EntryNo: Integer;
        SetBefore: Integer;
        EntriesBefore: Integer;
    begin
        // [GIVEN] Two entries
        Initialize(false);
        EntryNo := SeedGLEntry(DocumentTok, ValueATok);
        SeedGLEntry(DocumentTok, ValueATok);
        GLEntry.Get(EntryNo);
        SetBefore := GLEntry."Dimension Set ID";
        EntriesBefore := GLEntry.Count();
        // [WHEN] Previewing both
        Reply := Invoke(StrSubstNo('{"selection":[{"documentNo":"%1"}],"changes":[{"code":"%2","action":"set","value":"%3"}]}', DocumentTok, DimensionTok, ValueBTok));
        // [THEN] No ledger row changed
        AssertSuccess(Reply);
        GLEntry.Get(EntryNo);
        Assert.AreEqual(SetBefore, GLEntry."Dimension Set ID", 'Set unchanged');
        Assert.AreEqual(EntriesBefore, GLEntry.Count(), 'No entry added');
        // [WHEN] maxRows is 1
        Reply := Invoke(StrSubstNo('{"selection":[{"documentNo":"%1"}],"changes":[{"code":"%2","action":"remove"}],"maxRows":1}', DocumentTok, DimensionTok));
        // [THEN] The call is refused with the narrowing next step
        AssertRefusal(Reply, 'InvalidParameter');
        Assert.AreEqual('narrow the selection', Reply.GetText('nextStep'), 'Next step');
    end;

    /// <summary>AC1: invalid requests are refused with typed errors.</summary>
    [Test]
    procedure Scenario_AC01_InvalidRequestsAreRefused()
    begin
        Initialize(false);
        AssertRefusal(Invoke('{"changes":[{"code":"XDIMT","action":"remove"}]}'), 'MissingParameter');
        AssertRefusal(Invoke('{"selection":[{"documentNo":"X"}]}'), 'MissingParameter');
        AssertRefusal(Invoke('{"selection":"x","changes":[]}'), 'InvalidParameterFormat');
        AssertRefusal(Invoke('{"selection":[{"target":"Nope","entryNos":[1]}],"changes":[{"code":"XDIMT","action":"remove"}]}'), 'InvalidParameter');
        AssertRefusal(Invoke('{"selection":[{"target":"G/L Entry"}],"changes":[{"code":"XDIMT","action":"remove"}]}'), 'InvalidParameter');
        AssertRefusal(Invoke('{"selection":[{"documentNo":"X"}],"changes":[{"code":"XDIMT","action":"explode"}]}'), 'InvalidParameter');
        AssertRefusal(Invoke('{"selection":[{"documentNo":"X"}],"changes":[{"code":"XDIMT","action":"set"}]}'), 'InvalidParameter');
        AssertRefusal(Invoke('{"selection":[{"documentNo":"X"}],"changes":[{"code":"XDIMT","action":"remove"}],"maxRows":0}'), 'InvalidParameter');
    end;

    /// <summary>AC6: help carries description, parameters, response, examples and Icelandic keywords.</summary>
    [Test]
    procedure Scenario_AC06_HelpInEnglishAndIcelandic()
    var
        Impl: Codeunit "Dim Corr Preview Impl ori";
        Parameters: JsonArray;
        Response: JsonObject;
        Examples: JsonArray;
        Errors: JsonArray;
        SavedLanguage: Integer;
    begin
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Assert.IsTrue(Impl.GetParameters(Parameters), 'Parameters chapter');
        Assert.IsTrue(Impl.GetResponse(Response), 'Response chapter');
        Assert.IsTrue(Impl.GetErrors(Errors), 'Errors chapter');
        Assert.IsTrue(Impl.GetExamples(Examples), 'Examples chapter');
        Assert.AreEqual(2, Examples.Count(), 'Department change and project removal');
        Assert.IsTrue(StrPos(Impl.GetKeywords(), 'dimension correction preview') > 0, 'English keywords');
        Assert.IsTrue(StrPos(Impl.GetDescription(), 'Previews') > 0, 'English description');
        GlobalLanguage(1039);
        Assert.IsTrue(StrPos(Impl.GetKeywords(), 'forskoðun víddaleiðréttingar') > 0, 'Icelandic keywords: ' + Impl.GetKeywords());
        Assert.IsTrue(StrPos(Impl.GetDescription(), 'Forskoðar') > 0, 'Icelandic description');
        GlobalLanguage(SavedLanguage);
    end;

    /// <summary>AC6: the validation messages of the engine are translated when the language is Icelandic.</summary>
    [Test]
    procedure Scenario_AC06_ValidationMessageInIcelandic()
    var
        Engine: Codeunit "Dim Corr. Engine ori";
        Selection: JsonArray;
        Changes: JsonArray;
        Item: JsonObject;
        Keys: JsonArray;
        Result: JsonObject;
        Message: Text;
        EntryNo: Integer;
        SavedLanguage: Integer;
    begin
        Initialize(false);
        EntryNo := SeedGLEntry(DocumentTok, ValueATok);
        Item.Add('target', 'G/L Entry');
        Keys.Add(Format(EntryNo));
        Item.Add('entryNos', Keys);
        Selection.Add(Item);
        Clear(Item);
        Item.Add('code', 'XNOPE');
        Item.Add('action', 'remove');
        Item.Add('value', '');
        Changes.Add(Item);
        SavedLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Assert.IsTrue(Engine.Preview(Selection, Changes, 5000, Result), 'Preview computed');
        Message := Result.GetArray('rows').GetObject(0).GetText('reason');
        GlobalLanguage(SavedLanguage);
        Assert.AreEqual('refused', Result.GetArray('rows').GetObject(0).GetText('status'), 'Refused in 1039');
        Assert.IsTrue(StrPos(Message, 'er ekki til') > 0, 'Icelandic failure: ' + Message);
        SetSetup(true, '[]');
    end;

    local procedure FirstFailure(Reply: JsonObject): JsonObject
    begin
        AssertSuccess(Reply);
        exit(Reply.GetArray('rows').GetObject(0).GetArray('failures').GetObject(0));
    end;

    local procedure RowFor(Reply: JsonObject; TableName: Text; KeyField: Text; KeyValue: Text) Row: JsonObject
    var
        Token: JsonToken;
        Item: JsonToken;
        KeyToken: JsonToken;
    begin
        foreach Item in Reply.GetArray('rows') do
            if Item.AsObject().GetText('table') = TableName then
                if Item.AsObject().GetObject('key').Get(KeyField, KeyToken) then
                    if KeyToken.AsValue().AsText() = KeyValue then
                        exit(Item.AsObject());
        Assert.Fail('Row not found: ' + TableName + ' ' + KeyValue);
        Clear(Token);
    end;

    local procedure RowStatus(Reply: JsonObject; TableName: Text; KeyField: Text; KeyValue: Text): Text
    begin
        exit(RowFor(Reply, TableName, KeyField, KeyValue).GetText('status'));
    end;

    local procedure RowReason(Reply: JsonObject; TableName: Text; KeyField: Text; KeyValue: Text): Text
    begin
        exit(RowFor(Reply, TableName, KeyField, KeyValue).GetText('reason'));
    end;

    local procedure Initialize(RequireReason: Boolean)
    var
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
        GLEntry: Record "G/L Entry";
        CustEntry: Record "Cust. Ledger Entry";
        InvoiceHeader: Record "Sales Invoice Header";
        InvoiceLine: Record "Sales Invoice Line";
        DefaultDimension: Record "Default Dimension";
        Combination: Record "Dimension Combination";
    begin
        GLEntry.SetFilter("Document No.", 'XDIMT*');
        GLEntry.DeleteAll(false);
        CustEntry.SetFilter("Document No.", 'XDIMT*');
        CustEntry.DeleteAll(false);
        InvoiceHeader.SetFilter("No.", 'XDIMT*');
        InvoiceHeader.DeleteAll(false);
        InvoiceLine.SetFilter("Document No.", 'XDIMT*');
        InvoiceLine.DeleteAll(false);
        DefaultDimension.SetRange("Table ID", 18);
        DefaultDimension.SetRange("No.", CustomerTok);
        DefaultDimension.DeleteAll(false);
        Combination.SetRange("Dimension 1 Code", DimensionTok);
        Combination.DeleteAll(false);
        SetSetup(RequireReason, '[]');
        InsertDimension(DimensionTok);
        InsertDimension(OtherDimensionTok);
        InsertValue(DimensionTok, ValueATok, false);
        InsertValue(DimensionTok, ValueBTok, false);
        InsertValue(DimensionTok, ValueHeadingTok, true);
        InsertValue(OtherDimensionTok, OtherValueTok, false);
        Dimension.Get(DimensionTok);
        Dimension.Blocked := false;
        Dimension.Modify();
        DimensionValue.Get(DimensionTok, ValueBTok);
        DimensionValue.Blocked := false;
        DimensionValue.Modify();
    end;

    local procedure SetSetup(RequireReason: Boolean; BlockedList: Text)
    var
        Reply: JsonObject;
        Dispatcher: Codeunit "Dispatcher ori";
        Request: BigText;
        Response: BigText;
        ResponseType: Text[100];
        TextResponse: Text;
        RequireText: Text;
    begin
        if RequireReason then
            RequireText := 'true'
        else
            RequireText := 'false';
        Request.AddText(StrSubstNo('{"requireReason":%1,"blockedDimensions":%2}', RequireText, BlockedList));
        Dispatcher.Execute(Enum::"Message Type ori"::"Dimensions.Setup.Set", Enum::"Message Version ori"::"1.0", '', 'XDIMTST', 'application/json', Request, Response, ResponseType, true);
        Response.GetSubText(TextResponse, 1);
        Reply.ReadFrom(TextResponse);
        Assert.AreEqual('Success', Reply.GetText('status'), 'Setup set: ' + TextResponse);
    end;

    local procedure InsertDimension(DimensionCode: Text)
    var
        Dimension: Record Dimension;
    begin
        if Dimension.Get(DimensionCode) then
            exit;
        Dimension.Init();
        Dimension.Code := CopyStr(DimensionCode, 1, MaxStrLen(Dimension.Code));
        Dimension.Name := Dimension.Code;
        Dimension.Insert(false);
    end;

    local procedure InsertValue(DimensionCode: Text; ValueCode: Text; Heading: Boolean)
    var
        DimensionValue: Record "Dimension Value";
    begin
        if DimensionValue.Get(DimensionCode, ValueCode) then
            exit;
        DimensionValue.Init();
        DimensionValue."Dimension Code" := CopyStr(DimensionCode, 1, MaxStrLen(DimensionValue."Dimension Code"));
        DimensionValue.Code := CopyStr(ValueCode, 1, MaxStrLen(DimensionValue.Code));
        if Heading then
            DimensionValue."Dimension Value Type" := DimensionValue."Dimension Value Type"::Heading;
        DimensionValue.Insert(true);
    end;

    local procedure DimensionSetFor(CodeOne: Text; ValueOne: Text; CodeTwo: Text; ValueTwo: Text): Integer
    var
        TempSetEntry: Record "Dimension Set Entry" temporary;
        DimensionManagement: Codeunit DimensionManagement;
    begin
        AddSetEntry(TempSetEntry, CodeOne, ValueOne);
        AddSetEntry(TempSetEntry, CodeTwo, ValueTwo);
        if TempSetEntry.IsEmpty() then
            exit(0);
        exit(DimensionManagement.GetDimensionSetID(TempSetEntry));
    end;

    local procedure AddSetEntry(var TempSetEntry: Record "Dimension Set Entry" temporary; DimensionCode: Text; ValueCode: Text)
    var
        DimensionValue: Record "Dimension Value";
    begin
        if (DimensionCode = '') or (ValueCode = '') then
            exit;
        DimensionValue.Get(DimensionCode, ValueCode);
        TempSetEntry.Init();
        TempSetEntry."Dimension Code" := DimensionValue."Dimension Code";
        TempSetEntry."Dimension Value Code" := DimensionValue.Code;
        TempSetEntry."Dimension Value ID" := DimensionValue."Dimension Value ID";
        TempSetEntry.Insert();
    end;

    local procedure SeedGLEntry(DocumentNo: Text; ValueCode: Text): Integer
    begin
        exit(SeedGLEntryTwo(DocumentNo, ValueCode, ''));
    end;

    local procedure SeedGLEntryTwo(DocumentNo: Text; ValueCode: Text; OtherValueCode: Text): Integer
    var
        GLEntry: Record "G/L Entry";
    begin
        GLEntry.Init();
        if GLEntry.FindLast() then
            GLEntry."Entry No." += 1
        else
            GLEntry."Entry No." := 1;
        GLEntry."Document No." := CopyStr(DocumentNo, 1, MaxStrLen(GLEntry."Document No."));
        GLEntry."Posting Date" := 20260115D;
        GLEntry.Description := 'Dimensions preview test';
        GLEntry."Dimension Set ID" := DimensionSetFor(DimensionTok, ValueCode, OtherDimensionTok, OtherValueCode);
        GLEntry.Insert(false);
        exit(GLEntry."Entry No.");
    end;

    local procedure SeedCustEntry(ValueCode: Text): Integer
    var
        CustEntry: Record "Cust. Ledger Entry";
    begin
        CustEntry.Init();
        if CustEntry.FindLast() then
            CustEntry."Entry No." += 1
        else
            CustEntry."Entry No." := 1;
        CustEntry."Document No." := CopyStr(DocumentTok, 1, MaxStrLen(CustEntry."Document No."));
        CustEntry."Customer No." := CopyStr(CustomerTok, 1, MaxStrLen(CustEntry."Customer No."));
        CustEntry."Posting Date" := 20260115D;
        CustEntry."Dimension Set ID" := DimensionSetFor(DimensionTok, ValueCode, '', '');
        CustEntry.Insert(false);
        exit(CustEntry."Entry No.");
    end;

    local procedure SeedSalesInvoice(DocumentNo: Text; HeaderValue: Text; LineOneValue: Text; LineTwoValue: Text)
    var
        Header: Record "Sales Invoice Header";
        Line: Record "Sales Invoice Line";
    begin
        Header.Init();
        Header."No." := CopyStr(DocumentNo, 1, MaxStrLen(Header."No."));
        Header."Posting Date" := 20260115D;
        Header."Dimension Set ID" := DimensionSetFor(DimensionTok, HeaderValue, '', '');
        Header.Insert(false);
        Line.Init();
        Line."Document No." := Header."No.";
        Line."Line No." := 10000;
        Line."Dimension Set ID" := DimensionSetFor(DimensionTok, LineOneValue, '', '');
        Line.Insert(false);
        Line."Line No." := 20000;
        Line."Dimension Set ID" := DimensionSetFor(DimensionTok, LineTwoValue, '', '');
        Line.Insert(false);
    end;

    local procedure Invoke(Body: Text) Reply: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        Request: BigText;
        Response: BigText;
        ResponseType: Text[100];
        TextResponse: Text;
    begin
        Request.AddText(Body);
        Dispatcher.Execute(Enum::"Message Type ori"::"Dimensions.Correction.Preview", Enum::"Message Version ori"::"1.0", '', 'XDIMTST', 'application/json', Request, Response, ResponseType, true);
        Response.GetSubText(TextResponse, 1);
        Assert.IsTrue(Reply.ReadFrom(TextResponse), 'Structured dispatch response');
    end;

    local procedure AssertSuccess(Reply: JsonObject)
    begin
        Assert.AreEqual('Success', Reply.GetText('status'), 'Preview succeeded: ' + Format(Reply));
    end;

    local procedure AssertRefusal(Reply: JsonObject; ExpectedCode: Text)
    begin
        Assert.AreEqual('Error', Reply.GetText('status'), 'Refusal: ' + Format(Reply));
        Assert.AreEqual(ExpectedCode, Reply.GetText('code'), 'Typed code: ' + Format(Reply));
        Assert.IsTrue(Reply.GetText('nextStep') <> '', 'Actionable next step');
    end;
}
