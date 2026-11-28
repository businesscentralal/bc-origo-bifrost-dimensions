namespace Origo.Bifrost.Dimensions;

using Origo.Bifrost;

/// <summary>
/// Dimensions.Correction.Preview: computes what a dimension correction would do and whether it is allowed, without
/// writing business data. Only Dimension Set records may be created, which is not business data.
/// </summary>
codeunit 10076500 "Dim Corr Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    Permissions = tabledata "Dimension Corr. Setup ori" = r;

    var
        Engine: Codeunit "Dim Corr. Engine ori";
        Registry: Codeunit "Dim Target Registry ori";
        Selection: JsonArray;
        Changes: JsonArray;
        MaxRows: Integer;
        DescriptionLbl: Label 'Previews a dimension correction on posted entries and documents: cascade, validation, new dimension sets and a preview token. Nothing is corrected.', MaxLength = 250, Comment = 'is-IS=Forskoðar víddaleiðréttingu á bókuðum færslum og skjölum: dreifingu, sannprófun, ný víddarsett og forskoðunarlykil. Engu er breytt.';
        KeywordsLbl: Label 'dimension correction preview, correct dimensions, change department, remove dimension, posted documents, validation, cascade, preview token', Comment = 'is-IS=forskoðun víddaleiðréttingar, leiðrétta víddir, breyta deild, fjarlægja vídd, bókuð skjöl, sannprófun, dreifing, forskoðunarlykill, víddaleiðrétting';
        NotesLbl: Label 'Submit to POST /queues. Nothing is corrected: only Dimension Set records may be created. A header selection cascades to its lines and, for a documentNo selection, to the ledger entries of that document, only where their dimension set equals the header''s original set; others are skipped with reason "own dimensions". reason is required when the setup says so (Dimensions.Setup.Get). The previewToken is a hash of the selection, the changes and every row''s Dimension Set ID and expires after 30 minutes; above maxRows (default 5000) the call is refused.', Comment = 'is-IS=Sendist á POST /queues. Engu er leiðrétt: aðeins víddarsett geta orðið til. Val á hausi dreifist á línur hans og, við val á documentNo, á færslur skjalsins, aðeins þar sem víddarsettið er það sama og upprunalegt sett hauss; aðrar eru sniðgengnar með ástæðunni "own dimensions". reason er skylda ef uppsetningin krefst þess (Dimensions.Setup.Get). previewToken er hakk af valinu, breytingunum og víddarsetti hverrar línu og rennur út eftir 30 mínútur; yfir maxRows (sjálfgefið 5000) er kallinu hafnað.';
        SelectionMissingLbl: Label 'selection is missing.', Comment = 'is-IS=selection vantar.';
        SelectionNextLbl: Label 'Send selection as an array of {target, entryNos} and/or {documentNo, target}.', Comment = 'is-IS=Sendu selection sem fylki af {target, entryNos} og/eða {documentNo, target}.';
        SelectionItemLbl: Label 'Each selection item needs target with entryNos, or documentNo; target must be a supported table.', Comment = 'is-IS=Hvert val þarf target með entryNos, eða documentNo; target verður að vera studd tafla.';
        SelectionItemNextLbl: Label 'Send {target, entryNos} or {documentNo, target}, using the registry names from Dimensions.Entries.Find.', Comment = 'is-IS=Sendu {target, entryNos} eða {documentNo, target} með heitum úr skránni í Dimensions.Entries.Find.';
        TargetUnknownLbl: Label 'The target is not a supported table. Valid targets: %1.', Comment = '%1 = comma separated registry names; is-IS=Markmiðið er ekki studd tafla. Gild markmið: %1.';
        ChangesMissingLbl: Label 'changes is missing.', Comment = 'is-IS=changes vantar.';
        ChangesNextLbl: Label 'Send changes as an array of {code, action: "set"|"remove", value}.', Comment = 'is-IS=Sendu changes sem fylki af {code, action: "set"|"remove", value}.';
        ChangeItemLbl: Label 'Each change needs code, action "set" or "remove", and a value when the action is set.', Comment = 'is-IS=Hver breyting þarf code, action "set" eða "remove", og value ef action er set.';
        ChangeItemNextLbl: Label 'Send {code, action: "set", value} to replace or add a value, or {code, action: "remove"} to delete the dimension.', Comment = 'is-IS=Sendu {code, action: "set", value} til að skipta um eða bæta við gildi, eða {code, action: "remove"} til að eyða víddinni.';
        ReasonMissingLbl: Label 'reason is required by the dimension correction setup.', Comment = 'is-IS=Uppsetning víddaleiðréttinga krefst reason.';
        ReasonNextLbl: Label 'Send reason as text, or turn requireReason off with Dimensions.Setup.Set.', Comment = 'is-IS=Sendu reason sem texta, eða slökktu á requireReason með Dimensions.Setup.Set.';
        FormatLbl: Label '%1 has the wrong type.', Comment = '%1 = parameter name; is-IS=%1 er af röngu tagi.';
        FormatNextLbl: Label 'Send arrays for selection and changes, text for reason and a whole number for maxRows.', Comment = 'is-IS=Sendu fylki fyrir selection og changes, texta fyrir reason og heiltölu fyrir maxRows.';
        MaxRowsLbl: Label 'maxRows must be a whole number from 1 to 100000.', Comment = 'is-IS=maxRows verður að vera heiltala frá 1 til 100000.';
        MaxRowsNextLbl: Label 'Send maxRows between 1 and 100000, or omit it for 5000.', Comment = 'is-IS=Sendu maxRows á bilinu 1 til 100000, eða slepptu því fyrir 5000.';
        TooManyLbl: Label 'The selection has more than %1 rows.', Comment = '%1 = maxRows; is-IS=Valið inniheldur fleiri en %1 línur.';
        TooManyNextLbl: Label 'narrow the selection', Comment = 'is-IS=þrengdu valið';

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

    /// <summary>Validates the request and fills the response, or answers with a typed error.</summary>
    /// <param name="Argument">Request and response envelope.</param>
    procedure Execute(var Argument: Record "Message Argument ori")
    var
        Response: JsonObject;
    begin
        if not ReadRequest(Argument) then
            exit;
        if not Engine.Preview(Selection, Changes, MaxRows, Response) then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TooManyLbl, MaxRows), 'selection', '', '', TooManyNextLbl);
            exit;
        end;
        Response.Add('status', 'Success');
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ReadRequest(var Argument: Record "Message Argument ori"): Boolean
    var
        Setup: Record "Dimension Corr. Setup ori";
        Request: JsonObject;
        Token: JsonToken;
        Reason: Text;
    begin
        Request := Argument.GetRequestJson();
        MaxRows := 5000;
        if Request.Get('maxRows', Token) then
            if not ReadMaxRows(Token) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, MaxRowsLbl, 'maxRows', '', '', MaxRowsNextLbl);
                exit(false);
            end;
        if not Request.Get('selection', Token) then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::MissingParameter, SelectionMissingLbl, 'selection', '', '', SelectionNextLbl);
            exit(false);
        end;
        if not Token.IsArray() then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'selection'), 'selection', '', '', FormatNextLbl);
            exit(false);
        end;
        if not ReadSelection(Argument, Token.AsArray()) then
            exit(false);
        if not Request.Get('changes', Token) then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::MissingParameter, ChangesMissingLbl, 'changes', '', '', ChangesNextLbl);
            exit(false);
        end;
        if not Token.IsArray() then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'changes'), 'changes', '', '', FormatNextLbl);
            exit(false);
        end;
        if not ReadChanges(Argument, Token.AsArray()) then
            exit(false);
        if Request.Get('reason', Token) then
            if not ReadString(Token, Reason) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'reason'), 'reason', '', '', FormatNextLbl);
                exit(false);
            end;
        Setup.ReadIsolation := IsolationLevel::ReadCommitted;
        Setup.GetOrDefault();
        if Setup."Require Reason" and (DelChr(Reason, '<>', ' ') = '') then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::MissingParameter, ReasonMissingLbl, 'reason', '', '', ReasonNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadSelection(var Argument: Record "Message Argument ori"; Items: JsonArray): Boolean
    var
        Item: JsonToken;
        Entry: JsonObject;
        Token: JsonToken;
        Keys: JsonToken;
        Target: Enum "Dim. Correction Target ori";
        TargetName: Text;
        DocumentNo: Text;
        Normalized: JsonObject;
        KeyItem: JsonToken;
        NormalizedKeys: JsonArray;
        Serialized: Text;
    begin
        if Items.Count() = 0 then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, SelectionItemLbl, 'selection', '', '', SelectionItemNextLbl);
            exit(false);
        end;
        foreach Item in Items do begin
            Clear(Normalized);
            Clear(NormalizedKeys);
            TargetName := '';
            DocumentNo := '';
            if not Item.IsObject() then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'selection'), 'selection', '', '', FormatNextLbl);
                exit(false);
            end;
            Entry := Item.AsObject();
            if Entry.Get('target', Token) then
                if not ReadString(Token, TargetName) then begin
                    Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'selection.target'), 'selection', '', '', FormatNextLbl);
                    exit(false);
                end;
            if Entry.Get('documentNo', Token) then
                if not ReadString(Token, DocumentNo) then begin
                    Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'selection.documentNo'), 'selection', '', '', FormatNextLbl);
                    exit(false);
                end;
            if TargetName <> '' then
                if not Registry.FindTarget(TargetName, Target) then begin
                    Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, StrSubstNo(TargetUnknownLbl, Registry.ValidNames()), 'selection', '', '', SelectionItemNextLbl);
                    exit(false);
                end;
            if TargetName <> '' then
                Normalized.Add('target', TargetName);
            if DocumentNo <> '' then
                Normalized.Add('documentNo', DocumentNo);
            if Entry.Get('entryNos', Keys) then begin
                if (not Keys.IsArray()) or (TargetName = '') or (Keys.AsArray().Count() = 0) then begin
                    Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, SelectionItemLbl, 'selection', '', '', SelectionItemNextLbl);
                    exit(false);
                end;
                foreach KeyItem in Keys.AsArray() do begin
                    if (not KeyItem.IsValue()) or KeyItem.AsValue().IsNull() then begin
                        Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, SelectionItemLbl, 'selection', '', '', SelectionItemNextLbl);
                        exit(false);
                    end;
                    KeyItem.WriteTo(Serialized);
                    if CopyStr(Serialized, 1, 1) = '"' then
                        NormalizedKeys.Add(KeyItem.AsValue().AsText())
                    else
                        NormalizedKeys.Add(Serialized);
                end;
                Normalized.Add('entryNos', NormalizedKeys);
            end else
                if DocumentNo = '' then begin
                    Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, SelectionItemLbl, 'selection', '', '', SelectionItemNextLbl);
                    exit(false);
                end;
            Selection.Add(Normalized);
        end;
        exit(true);
    end;

    local procedure ReadChanges(var Argument: Record "Message Argument ori"; Items: JsonArray): Boolean
    var
        Item: JsonToken;
        Entry: JsonObject;
        Token: JsonToken;
        Normalized: JsonObject;
        CodeText: Text;
        ActionText: Text;
        ValueText: Text;
    begin
        if Items.Count() = 0 then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, ChangeItemLbl, 'changes', '', '', ChangeItemNextLbl);
            exit(false);
        end;
        foreach Item in Items do begin
            Clear(Normalized);
            ValueText := '';
            if not Item.IsObject() then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'changes'), 'changes', '', '', FormatNextLbl);
                exit(false);
            end;
            Entry := Item.AsObject();
            if not (Entry.Get('code', Token) and ReadString(Token, CodeText) and Entry.Get('action', Token) and ReadString(Token, ActionText)) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, ChangeItemLbl, 'changes', '', '', ChangeItemNextLbl);
                exit(false);
            end;
            ActionText := LowerCase(ActionText);
            if Entry.Get('value', Token) then
                if not ReadString(Token, ValueText) then begin
                    Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, 'changes.value'), 'changes', '', '', FormatNextLbl);
                    exit(false);
                end;
            if (CodeText = '') or not (ActionText in ['set', 'remove']) or ((ActionText = 'set') and (ValueText = '')) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, ChangeItemLbl, 'changes', '', '', ChangeItemNextLbl);
                exit(false);
            end;
            Normalized.Add('code', CodeText);
            Normalized.Add('action', ActionText);
            Normalized.Add('value', ValueText);
            Changes.Add(Normalized);
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
        exit((MaxRows >= 1) and (MaxRows <= 100000));
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
        Parameters.Add(Contracts.Parameter('selection', 'array', true, 'Array of {target, entryNos} (keys of one registry table; a document header cascades to its lines) and/or {documentNo, target} (header, lines and ledger entries of the document). Registry names: ' + Registry.ValidNames() + '.'));
        Parameters.Add(Contracts.Parameter('changes', 'array', true, 'Array of {code, action, value}. action "set" replaces or adds the value; "remove" deletes the dimension from the set.'));
        Parameters.Add(Contracts.Parameter('reason', 'string', false, 'Why the correction is made. Required when the setup has requireReason true (Dimensions.Setup.Get).'));
        Parameter := Contracts.Parameter('maxRows', 'integer', false, 'Largest number of rows the preview may return, 1 to 100000. Default 5000; above it the call is refused with nextStep "narrow the selection".');
        Parameter.Add('minimum', 1);
        Parameter.Add('maximum', 100000);
        Parameters.Add(Parameter);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Children: JsonArray;
        TotalChildren: JsonArray;
        Field: JsonObject;
    begin
        Fields.Add(Contracts.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contracts.ResponseField('rowCount', 'integer', 'Rows returned.'));
        Fields.Add(Contracts.ResponseField('okCount', 'integer', 'Rows with status ok.'));
        Fields.Add(Contracts.ResponseField('skippedCount', 'integer', 'Rows with status skipped.'));
        Fields.Add(Contracts.ResponseField('refusedCount', 'integer', 'Rows with status refused.'));
        TotalChildren.Add(Contracts.ResponseField('table', 'string', 'Registry name; document lines carry the name plus Line.'));
        TotalChildren.Add(Contracts.ResponseField('rows', 'integer', 'Rows of the table.'));
        TotalChildren.Add(Contracts.ResponseField('ok', 'integer', 'Rows ok.'));
        TotalChildren.Add(Contracts.ResponseField('skipped', 'integer', 'Rows skipped.'));
        TotalChildren.Add(Contracts.ResponseField('refused', 'integer', 'Rows refused.'));
        Field := Contracts.ResponseField('totals', 'array', 'Totals per table.');
        Field.Add('children', TotalChildren);
        Fields.Add(Field);
        Children.Add(Contracts.ResponseField('table', 'string', 'Registry name; document lines carry the name plus Line.'));
        Children.Add(Contracts.ResponseField('key', 'object', 'Primary key field names and values of the row.'));
        Children.Add(Contracts.ResponseField('dimensionSetId', 'integer', 'Current Dimension Set ID.'));
        Children.Add(Contracts.ResponseField('oldDimensions', 'array', 'Current {code, value} list.'));
        Children.Add(Contracts.ResponseField('newDimensions', 'array', 'New {code, value} list; absent when the row is skipped by the cascade rule or refused by the changes.'));
        Children.Add(Contracts.ResponseField('newDimensionSetId', 'integer', 'Dimension Set ID of the new list; the set may have been created.'));
        Children.Add(Contracts.ResponseField('status', 'string', 'ok, skipped or refused.'));
        Children.Add(Contracts.ResponseField('reason', 'string', 'Why a row is skipped ("own dimensions", "unchanged") or refused (first failure).'));
        Children.Add(Contracts.ResponseField('failures', 'array', 'Refused rows: objects {table, key, rule, message, nextStep}.'));
        Field := Contracts.ResponseField('rows', 'array', 'One row per header, line or ledger entry in the selection.');
        Field.Add('children', Children);
        Fields.Add(Field);
        Fields.Add(Contracts.ResponseField('previewToken', 'string', 'Hash of the selection, the changes and every row''s current Dimension Set ID.'));
        Fields.Add(Contracts.ResponseField('expiresAt', 'string', 'UTC time the preview expires, 30 minutes after the call.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        Response.Add('whenEmpty', 'Success with rowCount 0 and an empty rows array.');
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::MissingParameter, 'selection or changes is missing, or reason is missing while the setup requires it.', 'Send the missing parameter; read requireReason with Dimensions.Setup.Get.'));
        Errors.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::InvalidParameter, 'Unknown target, a selection item or change without the needed fields, an unknown action, maxRows outside 1-100000, or more rows than maxRows (nextStep "narrow the selection").', 'Follow the parameters chapter; nothing was corrected.'));
        Errors.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, 'A parameter has the wrong type.', 'Send arrays and text as described.'));
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'No posted entry or document is changed; Dimension Set records may be created.');
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
        Examples.Add(Contracts.Example('Change a department on one G/L transaction', '{"type":"Dimensions.Correction.Preview","data":{"selection":[{"target":"G/L Entry","entryNos":[1042]}],"changes":[{"code":"DEPARTMENT","action":"set","value":"SALES"}],"reason":"Posted to the wrong department"}}', '{"status":"Success","rowCount":1,"okCount":1,"skippedCount":0,"refusedCount":0,"totals":[{"table":"G/L Entry","rows":1,"ok":1,"skipped":0,"refused":0}],"rows":[{"table":"G/L Entry","key":{"Entry No.":1042},"dimensionSetId":5,"oldDimensions":[{"code":"DEPARTMENT","value":"ADM"}],"newDimensions":[{"code":"DEPARTMENT","value":"SALES"}],"newDimensionSetId":6,"status":"ok"}],"previewToken":"3F2A...","expiresAt":"2026-01-31T10:30:00Z"}'));
        Examples.Add(Contracts.Example('Remove a project dimension from a posted sales invoice and its lines', '{"type":"Dimensions.Correction.Preview","data":{"selection":[{"documentNo":"103001","target":"Sales Invoice"}],"changes":[{"code":"PROJECT","action":"remove"}],"reason":"Wrong project"}}', '{"status":"Success","rowCount":2,"okCount":1,"skippedCount":1,"refusedCount":0,"totals":[{"table":"Sales Invoice","rows":1,"ok":1,"skipped":0,"refused":0},{"table":"Sales Invoice Line","rows":1,"ok":0,"skipped":1,"refused":0}],"rows":[],"previewToken":"9C1B...","expiresAt":"2026-01-31T10:30:00Z"}'));
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
