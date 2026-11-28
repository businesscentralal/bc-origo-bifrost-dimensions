namespace Origo.Bifrost.Dimensions;

using Origo.Bifrost;
using Microsoft.Finance.Dimension;

/// <summary>
/// Dimensions.Entries.Find: finds posted ledger entries and posted documents by what they are and by their current dimensions.
/// The message is read-only: it never writes a record.
/// </summary>
codeunit 10076494 "Dimensions Find Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Registry: Codeunit "Dim Target Registry ori";
        DimensionCodes: List of [Text];
        DimensionValues: List of [Text];
        EntryKeys: List of [Text];
        DimensionTextCache: Dictionary of [Integer, Text];
        MatchCache: Dictionary of [Integer, Boolean];
        TargetName: Text;
        DocumentNo: Text;
        SourceNo: Text;
        PostingDateFrom: Date;
        PostingDateTo: Date;
        MaxRows: Integer;
        Remaining: Integer;
        Truncated: Boolean;
        IncludeLines: Boolean;
        DescriptionLbl: Label 'Finds posted ledger entries and posted documents by document no., posting date, source and current dimensions. Read-only; use it to pick what to correct.', MaxLength = 250, Comment = 'is-IS=Finnur bókaðar færslur og bókuð skjöl eftir skjalanúmeri, bókunardagsetningu, uppruna og núverandi víddum. Les eingöngu; notað til að velja hvað á að leiðrétta.';
        KeywordsLbl: Label 'dimensions, correct dimensions, dimension correction, posted entries, posted documents, find entries by dimension, dimension set', Comment = 'is-IS=víddir, leiðrétta víddir, víddaleiðrétting, bókaðar færslur, bókuð skjöl, finna færslur eftir víddum, víddasett';
        NotesLbl: Label 'Submit to POST /queues. Read-only: nothing is written. Without target, documentNo searches every supported table (header, lines and ledger entries). includeLines adds the document lines to a single document target. Row order follows the primary key of each table; truncated is true when more rows exist than maxRows.', Comment = 'is-IS=Sent á POST /queues. Les eingöngu: engu er breytt. Án target leitar documentNo í öllum studdum töflum (haus, línur og færslur). includeLines bætir línum skjals við eitt skjalamarkmið. Röð fylgir aðallykli hverrar töflu; truncated er true þegar fleiri línur eru til en maxRows.';
        TargetMissingLbl: Label 'target is missing. Send a registry name, or documentNo to search every table.', Comment = 'is-IS=target vantar. Sendu heiti úr skránni, eða documentNo til að leita í öllum töflum.';
        TargetUnknownLbl: Label 'The target is not a supported table. Valid targets: %1.', Comment = '%1 = comma separated registry names; is-IS=Markmiðið er ekki studd tafla. Gild markmið: %1.';
        TargetNextStepLbl: Label 'Send one of the valid target names exactly as listed.', Comment = 'is-IS=Sendu eitt af gildu heitunum nákvæmlega eins og þau eru skráð.';
        FormatLbl: Label '%1 has the wrong type.', Comment = '%1 = parameter name; is-IS=%1 er af röngu tagi.';
        FormatNextStepLbl: Label 'Send text for text parameters, YYYY-MM-DD for dates, a whole number for maxRows and arrays for dimensions and entryNos.', Comment = 'is-IS=Sendu texta fyrir textabreytur, ÁÁÁÁ-MM-DD fyrir dagsetningar, heiltölu fyrir maxRows og fylki fyrir dimensions og entryNos.';
        DimensionUnknownLbl: Label 'Dimension code %1 does not exist.', Comment = '%1 = dimension code; is-IS=Víddarkóðinn %1 er ekki til.';
        DimensionNextStepLbl: Label 'Use a dimension code from the Dimension list and send dimensions as an array of {code, value}; value "" means the dimension is missing.', Comment = 'is-IS=Notaðu víddarkóða úr víddalistanum og sendu dimensions sem fylki af {code, value}; value "" þýðir að vídd vantar.';
        DateRangeLbl: Label 'postingDateFrom is after postingDateTo.', Comment = 'is-IS=postingDateFrom er á eftir postingDateTo.';
        DateRangeNextStepLbl: Label 'Send postingDateFrom on or before postingDateTo.', Comment = 'is-IS=Sendu postingDateFrom sama dag eða á undan postingDateTo.';
        MaxRowsLbl: Label 'maxRows must be a whole number from 1 to 1000.', Comment = 'is-IS=maxRows verður að vera heiltala frá 1 til 1000.';
        MaxRowsNextStepLbl: Label 'Send maxRows between 1 and 1000, or omit it for 100.', Comment = 'is-IS=Sendu maxRows á bilinu 1 til 1000, eða slepptu því fyrir 100.';
        EntryNosLbl: Label 'entryNos needs a target, a list of at most 1000 keys, and keys without filter characters.', Comment = 'is-IS=entryNos þarf target, í mesta lagi 1000 lykla og lykla án síunartákna.';
        EntryNosNextStepLbl: Label 'Send target together with entryNos, using the keys of that table.', Comment = 'is-IS=Sendu target ásamt entryNos með lyklum þeirrar töflu.';

    /// <summary>Reports availability.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>No Foundation record filter is used.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Returns localized help.</summary>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Declares the read direction.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Returns localized search text.</summary>
    procedure GetKeywords(): Text
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection help.</summary>
    procedure GetSelectionDescription(): Text
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Runs the licensed request.</summary>
    /// <param name="Argument">Request and response envelope.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Execute(Argument);
    end;

    /// <summary>Validates the request and fills the response, or answers with a typed error. Nothing is written.</summary>
    /// <param name="Argument">Request and response envelope.</param>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
    begin
        if not ReadRequest(Argument) then
            exit;
        Response.Add('status', 'Success');
        Remaining := MaxRows;
        FillResponse(Response);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure FillResponse(var Response: JsonObject)
    var
        Descriptor: JsonObject;
        Rows: JsonArray;
        Groups: JsonArray;
        Group: JsonObject;
        Target: Enum "Dim. Correction Target ori";
        Targets: List of [Integer];
        Ordinal: Integer;
        Total: Integer;
        GroupRows: JsonArray;
    begin
        if TargetName <> '' then begin
            Registry.FindTarget(TargetName, Target);
            Descriptor := Describe(Target);
            CollectTarget(Descriptor, false, Rows);
            if IncludeLines and (DocumentNo <> '') then
                CollectTarget(Descriptor, true, Rows);
            Response.Add('rowCount', Rows.Count());
            Response.Add('truncated', Truncated);
            Response.Add('rows', Rows);
            exit;
        end;
        Registry.ListAvailable(Targets);
        foreach Ordinal in Targets do begin
            Target := Enum::"Dim. Correction Target ori".FromInteger(Ordinal);
            Descriptor := Describe(Target);
            Clear(GroupRows);
            CollectTarget(Descriptor, false, GroupRows);
            AddGroup(Groups, Descriptor, false, GroupRows, Total);
            if Descriptor.Contains('lineTableNo') then begin
                Clear(GroupRows);
                CollectTarget(Descriptor, true, GroupRows);
                AddGroup(Groups, Descriptor, true, GroupRows, Total);
            end;
        end;
        Response.Add('rowCount', Total);
        Response.Add('truncated', Truncated);
        Response.Add('groups', Groups);
        Clear(Group);
    end;

    local procedure AddGroup(var Groups: JsonArray; Descriptor: JsonObject; IsLine: Boolean; GroupRows: JsonArray; var Total: Integer)
    var
        Group: JsonObject;
        TableName: Text;
    begin
        if GroupRows.Count() = 0 then
            exit;
        TableName := Descriptor.GetText('name');
        if IsLine then
            TableName += ' Line';
        Group.Add('table', TableName);
        Group.Add('rowCount', GroupRows.Count());
        Group.Add('rows', GroupRows);
        Groups.Add(Group);
        Total += GroupRows.Count();
    end;

    local procedure Describe(Target: Enum "Dim. Correction Target ori") Descriptor: JsonObject
    var
        Implementation: Interface "Dim. Correction Target ori";
    begin
        Implementation := Target;
        Descriptor := Implementation.Describe(Target);
    end;

    local procedure CollectTarget(Descriptor: JsonObject; IsLine: Boolean; var Rows: JsonArray)
    var
        RecRef: RecordRef;
        Fields: Dictionary of [Text, Integer];
        TableNo: Integer;
        LinkField: Text;
        EntryKey: Text;
    begin
        if Truncated then
            exit;
        if IsLine then
            TableNo := Descriptor.GetInteger('lineTableNo')
        else
            TableNo := Descriptor.GetInteger('tableNo');
        RecRef.Open(TableNo);
        MapFields(RecRef, Fields);
        if not Fields.ContainsKey(Descriptor.GetText('dimensionSetIdField')) then
            exit;
        if IsLine then begin
            LinkField := Descriptor.GetText('lineLinkField');
            if (DocumentNo = '') or not Fields.ContainsKey(LinkField) then
                exit;
            if not FilterText(RecRef, Fields.Get(LinkField), DocumentNo) then
                exit;
        end else
            if not FilterHeaderOrLedger(RecRef, Fields, Descriptor) then
                exit;
        FilterStatus(RecRef, Fields, Descriptor);
        if (EntryKeys.Count() = 0) or IsLine then
            Scan(RecRef, Fields, Descriptor, IsLine, Rows)
        else
            foreach EntryKey in EntryKeys do
                if not Truncated then
                    if FilterKey(RecRef, Fields, Descriptor, EntryKey) then
                        Scan(RecRef, Fields, Descriptor, IsLine, Rows);
        RecRef.Close();
    end;

    local procedure FilterHeaderOrLedger(var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; Descriptor: JsonObject): Boolean
    var
        FieldName: Text;
    begin
        if DocumentNo <> '' then
            if not FilterText(RecRef, Fields.Get(Descriptor.GetText('documentNoField')), DocumentNo) then
                exit(false);
        if SourceNo <> '' then begin
            FieldName := Descriptor.GetText('sourceNoField');
            if not Fields.ContainsKey(FieldName) then
                exit(false);
            if not FilterText(RecRef, Fields.Get(FieldName), SourceNo) then
                exit(false);
        end;
        if (PostingDateFrom <> 0D) or (PostingDateTo <> 0D) then begin
            FieldName := Descriptor.GetText('postingDateField');
            if not Fields.ContainsKey(FieldName) then
                exit(false);
            if PostingDateTo = 0D then
                RecRef.Field(Fields.Get(FieldName)).SetFilter('%1..', PostingDateFrom)
            else
                if PostingDateFrom = 0D then
                    RecRef.Field(Fields.Get(FieldName)).SetFilter('..%1', PostingDateTo)
                else
                    RecRef.Field(Fields.Get(FieldName)).SetRange(PostingDateFrom, PostingDateTo);
        end;
        exit(true);
    end;

    local procedure FilterText(var RecRef: RecordRef; FieldNo: Integer; Value: Text): Boolean
    var
        FieldRef: FieldRef;
    begin
        FieldRef := RecRef.Field(FieldNo);
        if (FieldRef.Type() in [FieldType::Code, FieldType::Text]) and (StrLen(Value) > FieldRef.Length()) then
            exit(false);
        FieldRef.SetRange(Value);
        exit(true);
    end;

    local procedure FilterStatus(var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; Descriptor: JsonObject)
    begin
        if not Descriptor.Contains('statusField') then
            exit;
        if Fields.ContainsKey(Descriptor.GetText('statusField')) then
            RecRef.Field(Fields.Get(Descriptor.GetText('statusField'))).SetRange(Descriptor.GetInteger('statusValue'));
    end;

    local procedure FilterKey(var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; Descriptor: JsonObject; EntryKey: Text): Boolean
    var
        FieldRef: FieldRef;
        IntegerKey: Integer;
    begin
        FieldRef := RecRef.Field(Fields.Get(Descriptor.GetText('keyField')));
        if FieldRef.Type() in [FieldType::Integer, FieldType::BigInteger] then begin
            if not Evaluate(IntegerKey, EntryKey) then
                exit(false);
            FieldRef.SetRange(IntegerKey);
            exit(true);
        end;
        exit(FilterText(RecRef, FieldRef.Number(), EntryKey));
    end;

    local procedure Scan(var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; Descriptor: JsonObject; IsLine: Boolean; var Rows: JsonArray)
    var
        SetIdNo: Integer;
    begin
        SetIdNo := Fields.Get(Descriptor.GetText('dimensionSetIdField'));
        if RecRef.FindSet() then
            repeat
                if MatchesDimensions(RecRef.Field(SetIdNo).Value()) then begin
                    if Remaining = 0 then begin
                        Truncated := true;
                        exit;
                    end;
                    Rows.Add(BuildRow(RecRef, Fields, Descriptor, IsLine, SetIdNo));
                    Remaining -= 1;
                end;
            until RecRef.Next() = 0;
    end;

    local procedure BuildRow(var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; Descriptor: JsonObject; IsLine: Boolean; SetIdNo: Integer) Row: JsonObject
    var
        TableName: Text;
        SetId: Integer;
        DocumentField: Text;
        DimensionsArray: JsonArray;
        Json: Text;
    begin
        TableName := Descriptor.GetText('name');
        DocumentField := Descriptor.GetText('documentNoField');
        if IsLine then begin
            TableName += ' Line';
            DocumentField := Descriptor.GetText('lineLinkField');
        end;
        Row.Add('table', TableName);
        Row.Add('key', KeyObject(RecRef));
        AddField(Row, 'documentNo', RecRef, Fields, DocumentField);
        if not IsLine then begin
            AddField(Row, 'postingDate', RecRef, Fields, Descriptor.GetText('postingDateField'));
            AddField(Row, 'sourceNo', RecRef, Fields, Descriptor.GetText('sourceNoField'));
            AddField(Row, 'description', RecRef, Fields, Descriptor.GetText('descriptionField'));
        end else
            AddField(Row, 'description', RecRef, Fields, Descriptor.GetText('descriptionField'));
        Evaluate(SetId, Format(RecRef.Field(SetIdNo).Value()));
        Row.Add('dimensionSetId', SetId);
        Json := DimensionJson(SetId);
        DimensionsArray.ReadFrom(Json);
        Row.Add('dimensions', DimensionsArray);
    end;

    local procedure AddField(var Row: JsonObject; Name: Text; var RecRef: RecordRef; Fields: Dictionary of [Text, Integer]; FieldName: Text)
    var
        FieldRef: FieldRef;
    begin
        if not Fields.ContainsKey(FieldName) then
            exit;
        FieldRef := RecRef.Field(Fields.Get(FieldName));
        if FieldRef.Type() = FieldType::Date then
            Row.Add(Name, Format(FieldRef.Value(), 0, 9))
        else
            Row.Add(Name, Format(FieldRef.Value()));
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

    local procedure MatchesDimensions(SetIdValue: Variant): Boolean
    var
        SetId: Integer;
        Matches: Boolean;
    begin
        if DimensionCodes.Count() = 0 then
            exit(true);
        Evaluate(SetId, Format(SetIdValue));
        if MatchCache.Get(SetId, Matches) then
            exit(Matches);
        Matches := CheckDimensions(SetId);
        MatchCache.Add(SetId, Matches);
        exit(Matches);
    end;

    local procedure CheckDimensions(SetId: Integer): Boolean
    var
        SetEntry: Record "Dimension Set Entry";
        Index: Integer;
    begin
        for Index := 1 to DimensionCodes.Count() do begin
            if SetEntry.Get(SetId, CopyStr(DimensionCodes.Get(Index), 1, MaxStrLen(SetEntry."Dimension Code"))) then begin
                if UpperCase(SetEntry."Dimension Value Code") <> UpperCase(DimensionValues.Get(Index)) then
                    exit(false);
            end else
                if DimensionValues.Get(Index) <> '' then
                    exit(false);
        end;
        exit(true);
    end;

    local procedure DimensionJson(SetId: Integer) Json: Text
    var
        SetEntry: Record "Dimension Set Entry";
        Entries: JsonArray;
        Entry: JsonObject;
    begin
        if DimensionTextCache.Get(SetId, Json) then
            exit;
        SetEntry.SetRange("Dimension Set ID", SetId);
        if SetEntry.FindSet() then
            repeat
                Clear(Entry);
                Entry.Add('code', SetEntry."Dimension Code");
                Entry.Add('value', SetEntry."Dimension Value Code");
                Entries.Add(Entry);
            until SetEntry.Next() = 0;
        Entries.WriteTo(Json);
        DimensionTextCache.Add(SetId, Json);
    end;

    local procedure ReadRequest(var Argument: Record "Message Argument ori"): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        Value: Text;
        Target: Enum "Dim. Correction Target ori";
        Array: JsonArray;
    begin
        Request := Argument.GetRequestJson();
        MaxRows := 100;
        if Request.Get('maxRows', Token) then
            if not ReadMaxRows(Token) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, MaxRowsLbl, 'maxRows', '', '', MaxRowsNextStepLbl);
                exit(false);
            end;
        if not ReadOptionalText(Argument, Request, 'target', TargetName) then
            exit(false);
        if not ReadOptionalText(Argument, Request, 'documentNo', DocumentNo) then
            exit(false);
        if not ReadOptionalText(Argument, Request, 'sourceNo', SourceNo) then
            exit(false);
        if TargetName = '' then begin
            if DocumentNo = '' then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::MissingParameter, TargetMissingLbl, 'target', '', '', TargetNextStepLbl);
                exit(false);
            end;
        end else
            if not Registry.FindTarget(TargetName, Target) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TargetUnknownLbl, Registry.ValidNames()), 'target', '', '', TargetNextStepLbl);
                exit(false);
            end;
        if not ReadDate(Argument, Request, 'postingDateFrom', PostingDateFrom) then
            exit(false);
        if not ReadDate(Argument, Request, 'postingDateTo', PostingDateTo) then
            exit(false);
        if (PostingDateFrom <> 0D) and (PostingDateTo <> 0D) and (PostingDateFrom > PostingDateTo) then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, DateRangeLbl, 'postingDateFrom', '', '', DateRangeNextStepLbl);
            exit(false);
        end;
        if Request.Get('includeLines', Token) then
            if Token.IsValue() then
                IncludeLines := Token.AsValue().AsBoolean();
        if Request.Get('dimensions', Token) then begin
            if not Token.IsArray() then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'dimensions'), 'dimensions', '', '', FormatNextStepLbl);
                exit(false);
            end;
            if not ReadDimensions(Argument, Token.AsArray()) then
                exit(false);
        end;
        if Request.Get('entryNos', Token) then begin
            if not Token.IsArray() then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'entryNos'), 'entryNos', '', '', FormatNextStepLbl);
                exit(false);
            end;
            Array := Token.AsArray();
            if not ReadEntryNos(Array) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, EntryNosLbl, 'entryNos', '', '', EntryNosNextStepLbl);
                exit(false);
            end;
        end;
        exit(true);
    end;

    local procedure ReadMaxRows(Token: JsonToken): Boolean
    var
        Serialized: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Serialized);
        if not Evaluate(MaxRows, Serialized) then
            exit(false);
        exit((MaxRows >= 1) and (MaxRows <= 1000));
    end;

    local procedure ReadOptionalText(var Argument: Record "Message Argument ori"; Request: JsonObject; Name: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
    begin
        Value := '';
        if not Request.Get(Name, Token) then
            exit(true);
        if not ReadString(Token, Value) then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, Name), Name, '', '', FormatNextStepLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadDate(var Argument: Record "Message Argument ori"; Request: JsonObject; Name: Text; var Value: Date): Boolean
    var
        Token: JsonToken;
        Text: Text;
    begin
        Value := 0D;
        if not Request.Get(Name, Token) then
            exit(true);
        if ReadString(Token, Text) then
            if (Text = '') or Evaluate(Value, Text, 9) then
                exit(true);
        Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, Name), Name, '', '', FormatNextStepLbl);
        exit(false);
    end;

    local procedure ReadString(Token: JsonToken; var Value: Text): Boolean
    var
        Serialized: Text;
        Wrapper: JsonArray;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Serialized);
        if CopyStr(Serialized, 1, 1) <> '"' then
            exit(false);
        Wrapper.ReadFrom('[' + Serialized + ']');
        Wrapper.Get(0, Token);
        Value := Token.AsValue().AsText();
        exit(true);
    end;

    local procedure ReadDimensions(var Argument: Record "Message Argument ori"; Items: JsonArray): Boolean
    var
        Dimension: Record Dimension;
        Item: JsonToken;
        Token: JsonToken;
        Entry: JsonObject;
        CodeText: Text;
        ValueText: Text;
    begin
        foreach Item in Items do begin
            if not Item.IsObject() then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'dimensions'), 'dimensions', '', '', FormatNextStepLbl);
                exit(false);
            end;
            Entry := Item.AsObject();
            if not (Entry.Get('code', Token) and ReadString(Token, CodeText) and Entry.Get('value', Token) and ReadString(Token, ValueText)) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'dimensions'), 'dimensions', '', '', FormatNextStepLbl);
                exit(false);
            end;
            if (StrLen(CodeText) > MaxStrLen(Dimension.Code)) or not Dimension.Get(CopyStr(CodeText, 1, MaxStrLen(Dimension.Code))) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, StrSubstNo(DimensionUnknownLbl, CodeText), 'dimensions', '', '', DimensionNextStepLbl);
                exit(false);
            end;
            DimensionCodes.Add(Dimension.Code);
            DimensionValues.Add(ValueText);
        end;
        exit(true);
    end;

    local procedure ReadEntryNos(Items: JsonArray): Boolean
    var
        Item: JsonToken;
        Serialized: Text;
        KeyText: Text;
    begin
        if (TargetName = '') or (Items.Count() > 1000) then
            exit(false);
        foreach Item in Items do begin
            if not Item.IsValue() then
                exit(false);
            Item.WriteTo(Serialized);
            if Item.AsValue().IsNull() then
                exit(false);
            if CopyStr(Serialized, 1, 1) = '"' then
                KeyText := Item.AsValue().AsText()
            else
                KeyText := Serialized;
            EntryKeys.Add(KeyText);
        end;
        exit(true);
    end;

    /// <summary>Returns the envelope contract chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        Envelope.Add('endpoint', 'POST /queues');
        exit(true);
    end;

    /// <summary>Returns the target contract chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
        Parameter: JsonObject;
    begin
        Parameters.Add(Contracts.Parameter('target', 'string', false, 'One registry name: ' + Registry.ValidNames() + '. Required unless documentNo is given, which then searches every target.'));
        Parameters.Add(Contracts.Parameter('documentNo', 'string', false, 'Document no. of the entry, the posted document header or its lines.'));
        Parameters.Add(Contracts.Parameter('postingDateFrom', 'string', false, 'First posting date, YYYY-MM-DD.'));
        Parameters.Add(Contracts.Parameter('postingDateTo', 'string', false, 'Last posting date, YYYY-MM-DD; not before postingDateFrom.'));
        Parameters.Add(Contracts.Parameter('sourceNo', 'string', false, 'Source no. as the target defines it: account, customer, vendor, item, job and so on.'));
        Parameters.Add(Contracts.Parameter('dimensions', 'array', false, 'Array of {code, value} that must all match the current dimension set. value "" means the dimension is missing.'));
        Parameters.Add(Contracts.Parameter('entryNos', 'array', false, 'Explicit keys of the target (entry numbers, or document numbers for a document target). Needs target.'));
        Parameters.Add(Contracts.Parameter('includeLines', 'boolean', false, 'For a document target with documentNo: also return the lines of that document. Default false.'));
        Parameter := Contracts.Parameter('maxRows', 'integer', false, 'Maximum rows to return, 1 to 1000. Default 100.');
        Parameter.Add('minimum', 1);
        Parameter.Add('maximum', 1000);
        Parameters.Add(Parameter);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Children: JsonArray;
        Field: JsonObject;
    begin
        Fields.Add(Contracts.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contracts.ResponseField('rowCount', 'integer', 'Rows returned.'));
        Fields.Add(Contracts.ResponseField('truncated', 'boolean', 'True when more matching rows exist than maxRows.'));
        Children.Add(Contracts.ResponseField('table', 'string', 'Registry name; document lines carry the name plus Line.'));
        Children.Add(Contracts.ResponseField('key', 'object', 'Primary key field names and values of the row.'));
        Children.Add(Contracts.ResponseField('documentNo', 'string', 'Document no.'));
        Children.Add(Contracts.ResponseField('postingDate', 'string', 'Posting date, YYYY-MM-DD, where the table has one.'));
        Children.Add(Contracts.ResponseField('sourceNo', 'string', 'Source no. where the table has one.'));
        Children.Add(Contracts.ResponseField('description', 'string', 'Description where the table has one.'));
        Children.Add(Contracts.ResponseField('dimensionSetId', 'integer', 'Current Dimension Set ID.'));
        Children.Add(Contracts.ResponseField('dimensions', 'array', 'Objects {code, value} sorted by code.'));
        Field := Contracts.ResponseField('rows', 'array', 'One row per match when target is given.');
        Field.Add('children', Children);
        Fields.Add(Field);
        Fields.Add(Contracts.ResponseField('groups', 'array', 'Without target: objects {table, rowCount, rows} grouped by table; the maxRows cap applies to the total.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        Response.Add('whenEmpty', 'Success with rowCount 0 and an empty rows or groups array.');
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::MissingParameter, 'Neither target nor documentNo is given.', 'Send target, or documentNo to search every table.'));
        Errors.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::InvalidParameter, 'Unknown target (the valid names are listed), unknown dimension code, postingDateFrom after postingDateTo, maxRows outside 1-1000, or invalid entryNos.', 'Follow the parameters chapter; nothing was written.'));
        Errors.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, 'A parameter has the wrong type or date format.', 'Send text, YYYY-MM-DD dates and arrays as described.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'No database writes.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST DIMRead ori');
        exit(true);
    end;

    /// <summary>Returns the metering contract chapter.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the workflow contract chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contracts.Example('G/L entries by document no.', '{"type":"Dimensions.Entries.Find","data":{"target":"G/L Entry","documentNo":"G00001"}}', '{"status":"Success","rowCount":1,"truncated":false,"rows":[{"table":"G/L Entry","key":{"Entry No.":1},"documentNo":"G00001","postingDate":"2026-01-31","sourceNo":"","description":"Opening","dimensionSetId":5,"dimensions":[{"code":"DEPARTMENT","value":"ADM"}]}]}'));
        Examples.Add(Contracts.Example('Value entries by item and dimension', '{"type":"Dimensions.Entries.Find","data":{"target":"Value Entry","sourceNo":"1896-S","dimensions":[{"code":"DEPARTMENT","value":""}],"maxRows":50}}', '{"status":"Success","rowCount":0,"truncated":false,"rows":[]}'));
        Examples.Add(Contracts.Example('Posted sales invoice lines', '{"type":"Dimensions.Entries.Find","data":{"target":"Sales Invoice","documentNo":"103001","includeLines":true}}', '{"status":"Success","rowCount":2,"truncated":false,"rows":[{"table":"Sales Invoice","key":{"No.":"103001"},"documentNo":"103001","dimensionSetId":0,"dimensions":[]},{"table":"Sales Invoice Line","key":{"Document No.":"103001","Line No.":10000},"documentNo":"103001","dimensionSetId":0,"dimensions":[]}]}'));
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := DescriptionLbl;
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := NotesLbl;
        exit(true);
    end;
}
