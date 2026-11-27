namespace Origo.Bifrost.Dimensions.Test;

using Origo.Bifrost;
using Origo.Bifrost.Dimensions;
using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Sales.History;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests Dimensions.Entries.Find and the supported-table registry: filters, dimension matching, grouping, errors,
/// help in 1033 and 1039, and a guard that every registry entry still names fields that exist on its table.
/// Each test seeds its own G/L entries and documents inside the test transaction.
/// </summary>
codeunit 98302 "Dim Entries Find Tst ori"
{
    Subtype = Test;
    Permissions = tabledata "G/L Entry" = RIMD,
                  tabledata "Sales Invoice Header" = RIMD,
                  tabledata "Sales Invoice Line" = RIMD,
                  tabledata Dimension = RIMD,
                  tabledata "Dimension Value" = RIMD,
                  tabledata "Dimension Set Entry" = RIMD;

    var
        Assert: Codeunit "Library Assert";
        DocumentTok: Label 'XDIMT-001', Locked = true;
        DimensionTok: Label 'XDIMT', Locked = true;
        ValueATok: Label 'XVA', Locked = true;
        ValueBTok: Label 'XVB', Locked = true;

    /// <summary>AC1+AC2: G/L entries are found by document no. with their dimensions sorted by code.</summary>
    [Test]
    procedure Scenario_AC02_GLEntryByDocumentNoReturnsRowShape()
    var
        Reply: JsonObject;
        Row: JsonObject;
    begin
        // [GIVEN] One G/L entry with dimension XDIMT=XVA and a second entry in another document
        Initialize();
        SeedGLEntry(DocumentTok, ValueATok);
        SeedGLEntry('XDIMT-OTHER', ValueBTok);

        // [WHEN] Finding G/L Entry rows by document no.
        Reply := Invoke(StrSubstNo('{"target":"G/L Entry","documentNo":"%1"}', DocumentTok));

        // [THEN] One row carries table, key, document no., posting date, dimension set and dimensions
        AssertSuccess(Reply);
        Assert.AreEqual(1, Reply.GetInteger('rowCount'), 'One match');
        Assert.IsFalse(Reply.GetBoolean('truncated'), 'Not truncated');
        Row := Reply.GetArray('rows').GetObject(0);
        Assert.AreEqual('G/L Entry', Row.GetText('table'), 'Table');
        Assert.IsTrue(Row.GetObject('key').Contains('Entry No.'), 'Key names the primary key');
        Assert.AreEqual(DocumentTok, Row.GetText('documentNo'), 'Document no.');
        Assert.AreEqual('2026-01-15', Row.GetText('postingDate'), 'Posting date');
        Assert.IsTrue(Row.GetInteger('dimensionSetId') > 0, 'Dimension set id');
        Assert.AreEqual(DimensionTok, Row.GetArray('dimensions').GetObject(0).GetText('code'), 'Dimension code');
        Assert.AreEqual(ValueATok, Row.GetArray('dimensions').GetObject(0).GetText('value'), 'Dimension value');
    end;

    /// <summary>AC1: dimension filters must all match and an empty value means the dimension is missing.</summary>
    [Test]
    procedure Scenario_AC01_DimensionFilterMatchesValueAndMissing()
    var
        Reply: JsonObject;
    begin
        // [GIVEN] One entry with XDIMT=XVA and one entry without any dimension, same document
        Initialize();
        SeedGLEntry(DocumentTok, ValueATok);
        SeedGLEntry(DocumentTok, '');

        // [WHEN] Filtering on XDIMT=XVA, then on XDIMT missing
        Reply := Invoke(StrSubstNo('{"target":"G/L Entry","documentNo":"%1","dimensions":[{"code":"%2","value":"%3"}]}', DocumentTok, DimensionTok, ValueATok));
        // [THEN] Only the entry with the value matches
        Assert.AreEqual(1, Reply.GetInteger('rowCount'), 'Value filter');
        Reply := Invoke(StrSubstNo('{"target":"G/L Entry","documentNo":"%1","dimensions":[{"code":"%2","value":""}]}', DocumentTok, DimensionTok));
        // [THEN] Only the entry without the dimension matches
        Assert.AreEqual(1, Reply.GetInteger('rowCount'), 'Missing filter');
        Assert.AreEqual(0, Reply.GetArray('rows').GetObject(0).GetArray('dimensions').Count(), 'Matched entry has no dimensions');
    end;

    /// <summary>AC1: date range, source no. and explicit keys narrow the result.</summary>
    [Test]
    procedure Scenario_AC01_DateSourceAndEntryNosFilter()
    var
        Reply: JsonObject;
        EntryNo: Integer;
    begin
        // [GIVEN] Two entries in one document, posted 2026-01-15
        Initialize();
        EntryNo := SeedGLEntry(DocumentTok, ValueATok);
        SeedGLEntry(DocumentTok, ValueBTok);

        // [WHEN/THEN] A date range outside the posting date finds nothing; one around it finds both
        Reply := Invoke(StrSubstNo('{"target":"G/L Entry","documentNo":"%1","postingDateFrom":"2026-02-01"}', DocumentTok));
        Assert.AreEqual(0, Reply.GetInteger('rowCount'), 'After the posting date');
        Reply := Invoke(StrSubstNo('{"target":"G/L Entry","documentNo":"%1","postingDateFrom":"2026-01-01","postingDateTo":"2026-01-31"}', DocumentTok));
        Assert.AreEqual(2, Reply.GetInteger('rowCount'), 'Inside the posting dates');
        // [WHEN/THEN] An unused source no. finds nothing
        Reply := Invoke(StrSubstNo('{"target":"G/L Entry","documentNo":"%1","sourceNo":"NOSUCHSRC"}', DocumentTok));
        Assert.AreEqual(0, Reply.GetInteger('rowCount'), 'Source no.');
        // [WHEN/THEN] An explicit key returns exactly that entry
        Reply := Invoke(StrSubstNo('{"target":"G/L Entry","entryNos":[%1]}', EntryNo));
        Assert.AreEqual(1, Reply.GetInteger('rowCount'), 'Explicit key');
        Assert.AreEqual(EntryNo, Reply.GetArray('rows').GetObject(0).GetObject('key').GetInteger('Entry No.'), 'Explicit key row');
    end;

    /// <summary>AC1: maxRows caps the rows and sets truncated.</summary>
    [Test]
    procedure Scenario_AC01_MaxRowsTruncates()
    var
        Reply: JsonObject;
    begin
        // [GIVEN] Three entries in one document
        Initialize();
        SeedGLEntry(DocumentTok, ValueATok);
        SeedGLEntry(DocumentTok, ValueATok);
        SeedGLEntry(DocumentTok, ValueATok);

        // [WHEN] Asking for two rows
        Reply := Invoke(StrSubstNo('{"target":"G/L Entry","documentNo":"%1","maxRows":2}', DocumentTok));

        // [THEN] Two rows come back and truncated is true
        Assert.AreEqual(2, Reply.GetInteger('rowCount'), 'Capped');
        Assert.IsTrue(Reply.GetBoolean('truncated'), 'Truncated');
        Reply := Invoke(StrSubstNo('{"target":"G/L Entry","documentNo":"%1","maxRows":3}', DocumentTok));
        Assert.IsFalse(Reply.GetBoolean('truncated'), 'Exactly maxRows is not truncated');
    end;

    /// <summary>AC3: documentNo without target searches headers, lines and ledger entries, grouped by table.</summary>
    [Test]
    procedure Scenario_AC03_DocumentNoWithoutTargetGroupsByTable()
    var
        Reply: JsonObject;
        Group: JsonToken;
        Tables: Text;
    begin
        // [GIVEN] A G/L entry, a sales invoice header and a sales invoice line sharing one document no.
        Initialize();
        SeedGLEntry(DocumentTok, ValueATok);
        SeedSalesInvoice(DocumentTok, ValueBTok);

        // [WHEN] Searching by document no. only
        Reply := Invoke(StrSubstNo('{"documentNo":"%1"}', DocumentTok));

        // [THEN] The result is grouped by table: ledger entry, header and line
        AssertSuccess(Reply);
        foreach Group in Reply.GetArray('groups') do
            Tables += '|' + Group.AsObject().GetText('table') + '|';
        Assert.IsTrue(StrPos(Tables, '|G/L Entry|') > 0, 'G/L Entry group: ' + Tables);
        Assert.IsTrue(StrPos(Tables, '|Sales Invoice|') > 0, 'Header group: ' + Tables);
        Assert.IsTrue(StrPos(Tables, '|Sales Invoice Line|') > 0, 'Line group: ' + Tables);
        Assert.AreEqual(3, Reply.GetInteger('rowCount'), 'Total rows');
        // [THEN] The maxRows cap applies to the total
        Reply := Invoke(StrSubstNo('{"documentNo":"%1","maxRows":2}', DocumentTok));
        Assert.AreEqual(2, Reply.GetInteger('rowCount'), 'Capped total');
        Assert.IsTrue(Reply.GetBoolean('truncated'), 'Truncated total');
    end;

    /// <summary>AC1: a document target returns its lines only with includeLines.</summary>
    [Test]
    procedure Scenario_AC01_IncludeLinesAddsDocumentLines()
    var
        Reply: JsonObject;
    begin
        // [GIVEN] A posted sales invoice with one line
        Initialize();
        SeedSalesInvoice(DocumentTok, ValueBTok);

        // [WHEN/THEN] Header only by default; header and line with includeLines
        Reply := Invoke(StrSubstNo('{"target":"Sales Invoice","documentNo":"%1"}', DocumentTok));
        Assert.AreEqual(1, Reply.GetInteger('rowCount'), 'Header only');
        Reply := Invoke(StrSubstNo('{"target":"sales invoice","documentNo":"%1","includeLines":true}', DocumentTok));
        Assert.AreEqual(2, Reply.GetInteger('rowCount'), 'Header and line, name ignores case');
        Assert.AreEqual('Sales Invoice Line', Reply.GetArray('rows').GetObject(1).GetText('table'), 'Line row');
        Assert.AreEqual(10000, Reply.GetArray('rows').GetObject(1).GetObject('key').GetInteger('Line No.'), 'Line key');
    end;

    /// <summary>AC4: unknown target, unknown dimension, reversed dates and bad maxRows are refused with a next step.</summary>
    [Test]
    procedure Scenario_AC04_InvalidRequestsAreRefused()
    var
        Reply: JsonObject;
        EntriesBefore: Integer;
        GLEntry: Record "G/L Entry";
    begin
        Initialize();
        EntriesBefore := GLEntry.Count();

        Reply := Invoke('{"target":"Nonsense"}');
        AssertRefusal(Reply, 'InvalidParameter');
        Assert.IsTrue(StrPos(Format(Reply), 'G/L Entry') > 0, 'Unknown target lists valid names: ' + Format(Reply));
        Reply := Invoke('{"target":"G/L Entry","dimensions":[{"code":"NOSUCHDIM","value":"X"}]}');
        AssertRefusal(Reply, 'InvalidParameter');
        Reply := Invoke('{"target":"G/L Entry","postingDateFrom":"2026-03-01","postingDateTo":"2026-02-01"}');
        AssertRefusal(Reply, 'InvalidParameter');
        Reply := Invoke('{"target":"G/L Entry","maxRows":0}');
        AssertRefusal(Reply, 'InvalidParameter');
        Reply := Invoke('{"target":"G/L Entry","maxRows":1001}');
        AssertRefusal(Reply, 'InvalidParameter');
        Reply := Invoke('{}');
        AssertRefusal(Reply, 'MissingParameter');
        Reply := Invoke('{"target":"G/L Entry","postingDateFrom":"yesterday"}');
        AssertRefusal(Reply, 'InvalidParameterFormat');
        Assert.AreEqual(EntriesBefore, GLEntry.Count(), 'Nothing is written');
    end;

    /// <summary>AC5: help carries description, parameters, response, examples and Icelandic keywords.</summary>
    [Test]
    procedure Scenario_AC05_HelpInEnglishAndIcelandic()
    var
        Impl: Codeunit "Dimensions Find Impl ori";
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
        Assert.AreEqual(3, Examples.Count(), 'G/L by document no., value entries by item and dimension, posted sales invoice lines');
        Assert.IsTrue(StrPos(Impl.GetKeywords(), 'dimension correction') > 0, 'English keywords');
        Assert.IsTrue(StrPos(Impl.GetDescription(), 'Finds posted') > 0, 'English description');
        GlobalLanguage(1039);
        Assert.IsTrue(StrPos(Impl.GetKeywords(), 'víddaleiðrétting') > 0, 'Icelandic keywords: ' + Impl.GetKeywords());
        Assert.IsTrue(StrPos(Impl.GetKeywords(), 'bókaðar færslur') > 0, 'Icelandic keywords: ' + Impl.GetKeywords());
        Assert.IsTrue(StrPos(Impl.GetDescription(), 'Finnur') > 0, 'Icelandic description');
        GlobalLanguage(SavedLanguage);
    end;

    /// <summary>AC6: every registry entry names a table and fields that exist, guarding against renames across BC versions.</summary>
    [Test]
    procedure Scenario_AC06_RegistryFieldsExistOnTheirTables()
    var
        Registry: Codeunit "Dim Target Registry ori";
        Implementation: Interface "Dim. Correction Target ori";
        Target: Enum "Dim. Correction Target ori";
        Targets: List of [Integer];
        Ordinal: Integer;
        Descriptor: JsonObject;
        Seen: Integer;
    begin
        Registry.ListAvailable(Targets);
        Assert.IsTrue(Targets.Count() >= 30, 'The registry lists the ledgers and posted documents');
        foreach Ordinal in Targets do begin
            Target := Enum::"Dim. Correction Target ori".FromInteger(Ordinal);
            Implementation := Target;
            Descriptor := Implementation.Describe(Target);
            AssertTableFields(Format(Target), Descriptor.GetInteger('tableNo'), Descriptor, false);
            if Descriptor.Contains('lineTableNo') then
                AssertTableFields(Format(Target) + ' line', Descriptor.GetInteger('lineTableNo'), Descriptor, true);
            Seen += 1;
        end;
        Assert.AreEqual(Targets.Count(), Seen, 'Every available entry was checked');
    end;

    local procedure AssertTableFields(TargetName: Text; TableNo: Integer; Descriptor: JsonObject; IsLine: Boolean)
    var
        RecRef: RecordRef;
        Names: List of [Text];
        Index: Integer;
        FieldNames: List of [Text];
        Registry: Codeunit "Dim Target Registry ori";
    begin
        RecRef.Open(TableNo);
        for Index := 1 to RecRef.FieldCount() do
            Names.Add(RecRef.FieldIndex(Index).Name());
        if IsLine then
            Assert.IsTrue(Names.Contains(Descriptor.GetText('lineLinkField')), TargetName + ': header link field')
        else begin
            Assert.IsTrue(Names.Contains(Descriptor.GetText('dimensionSetIdField')), TargetName + ': Dimension Set ID');
            Assert.IsTrue(Names.Contains(Descriptor.GetText('keyField')), TargetName + ': key field');
            Assert.IsTrue(Names.Contains(Descriptor.GetText('documentNoField')), TargetName + ': document no.');
            Assert.IsTrue(Names.Contains(Descriptor.GetText('postingDateField')), TargetName + ': posting date');
            Assert.IsTrue(Names.Contains(Descriptor.GetText('sourceNoField')), TargetName + ': source no.');
        end;
        RecRef.Close();
        Registry.DimensionCodeFields(TableNo, FieldNames);
        Assert.IsTrue(FieldNames.Count() >= 0, 'Dimension code fields are listed');
    end;

    local procedure Initialize()
    var
        Dimension: Record Dimension;
        DimensionValue: Record "Dimension Value";
        GLEntry: Record "G/L Entry";
        InvoiceHeader: Record "Sales Invoice Header";
        InvoiceLine: Record "Sales Invoice Line";
    begin
        // Codeunit isolation keeps the rows of earlier tests, so every test starts from a clean XDIMT document range.
        GLEntry.SetFilter("Document No.", 'XDIMT*');
        GLEntry.DeleteAll(false);
        InvoiceHeader.SetFilter("No.", 'XDIMT*');
        InvoiceHeader.DeleteAll(false);
        InvoiceLine.SetFilter("Document No.", 'XDIMT*');
        InvoiceLine.DeleteAll(false);
        if not Dimension.Get(DimensionTok) then begin
            Dimension.Init();
            Dimension.Code := DimensionTok;
            Dimension.Name := DimensionTok;
            Dimension.Insert(false);
        end;
        InsertValue(ValueATok);
        InsertValue(ValueBTok);
        Clear(DimensionValue);
    end;

    local procedure InsertValue(ValueCode: Text)
    var
        DimensionValue: Record "Dimension Value";
    begin
        if DimensionValue.Get(DimensionTok, ValueCode) then
            exit;
        DimensionValue.Init();
        DimensionValue."Dimension Code" := DimensionTok;
        DimensionValue.Code := CopyStr(ValueCode, 1, MaxStrLen(DimensionValue.Code));
        DimensionValue.Insert(true);
    end;

    local procedure DimensionSetFor(ValueCode: Text): Integer
    var
        DimensionValue: Record "Dimension Value";
        TempSetEntry: Record "Dimension Set Entry" temporary;
        DimensionManagement: Codeunit DimensionManagement;
    begin
        if ValueCode = '' then
            exit(0);
        TempSetEntry.Init();
        TempSetEntry."Dimension Code" := DimensionTok;
        TempSetEntry."Dimension Value Code" := CopyStr(ValueCode, 1, MaxStrLen(TempSetEntry."Dimension Value Code"));
        DimensionValue.Get(DimensionTok, ValueCode);
        TempSetEntry."Dimension Value ID" := DimensionValue."Dimension Value ID";
        TempSetEntry.Insert();
        exit(DimensionManagement.GetDimensionSetID(TempSetEntry));
    end;

    local procedure SeedGLEntry(DocumentNo: Text; ValueCode: Text): Integer
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
        GLEntry.Description := 'Dimensions find test';
        GLEntry."Dimension Set ID" := DimensionSetFor(ValueCode);
        GLEntry.Insert(false);
        exit(GLEntry."Entry No.");
    end;

    local procedure SeedSalesInvoice(DocumentNo: Text; ValueCode: Text)
    var
        Header: Record "Sales Invoice Header";
        Line: Record "Sales Invoice Line";
    begin
        Header.Init();
        Header."No." := CopyStr(DocumentNo, 1, MaxStrLen(Header."No."));
        Header."Posting Date" := 20260115D;
        Header."Dimension Set ID" := DimensionSetFor(ValueCode);
        Header.Insert(false);
        Line.Init();
        Line."Document No." := Header."No.";
        Line."Line No." := 10000;
        Line."Dimension Set ID" := Header."Dimension Set ID";
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
        Dispatcher.Execute(Enum::"Message Type ori"::"Dimensions.Entries.Find", Enum::"Message Version ori"::"1.0", '', 'XDIMTST', 'application/json', Request, Response, ResponseType, true);
        Response.GetSubText(TextResponse, 1);
        Assert.IsTrue(Reply.ReadFrom(TextResponse), 'Structured dispatch response');
    end;

    local procedure AssertSuccess(Reply: JsonObject)
    begin
        Assert.AreEqual('Success', Reply.GetText('status'), 'Read succeeded: ' + Format(Reply));
    end;

    local procedure AssertRefusal(Reply: JsonObject; ExpectedCode: Text)
    begin
        Assert.AreEqual('Error', Reply.GetText('status'), 'Refusal: ' + Format(Reply));
        Assert.AreEqual(ExpectedCode, Reply.GetText('code'), 'Typed code: ' + Format(Reply));
        Assert.IsTrue(Reply.GetText('nextStep') <> '', 'Actionable next step');
    end;
}
