namespace Origo.Bifrost.Dimensions;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.Dimension.Correction;
using Origo.Bifrost;

/// <summary>
/// Runs Dimensions.Setup.Get and Dimensions.Setup.Set and builds their public contract chapters.
/// The blocked list returned is the union of this app's list and Microsoft's Dimension Correction blocked setup
/// (table "Dim Correction Blocked Setup"), which is only read and never written.
/// </summary>
codeunit 10076499 "Dim Setup Msg Mgt ori"
{
    Access = Internal;

    var
        BifrostSourceTok: Label 'bifrost', Locked = true;
        MicrosoftSourceTok: Label 'microsoft', Locked = true;
        ThresholdKeyTok: Label 'backgroundThreshold', Locked = true;
        RequireReasonKeyTok: Label 'requireReason', Locked = true;
        BlockedKeyTok: Label 'blockedDimensions', Locked = true;
        MinThreshold: Integer;
        MaxThreshold: Integer;
        NothingToSetErr: Label 'Send at least one of backgroundThreshold, requireReason or blockedDimensions.', Comment = 'is-IS=Sendu að minnsta kosti eitt af backgroundThreshold, requireReason eða blockedDimensions.';
        NothingToSetNextLbl: Label 'Use Dimensions.Setup.Get to read the current values, then send only the values to change.', Comment = 'is-IS=Notaðu Dimensions.Setup.Get til að lesa núverandi gildi og sendu síðan aðeins gildin sem á að breyta.';
        ThresholdFormatErr: Label 'backgroundThreshold must be a whole number.', Comment = 'is-IS=backgroundThreshold verður að vera heiltala.';
        ThresholdRangeErr: Label 'backgroundThreshold must be between %1 and %2.', Comment = '%1 = lowest allowed value, %2 = highest allowed value; is-IS=backgroundThreshold verður að vera á bilinu %1 til %2.';
        ThresholdNextLbl: Label 'Send a whole number of rows from 1 to 100000, for example 500.', Comment = 'is-IS=Sendu heiltölu lína frá 1 til 100000, til dæmis 500.';
        RequireReasonFormatErr: Label 'requireReason must be true or false.', Comment = 'is-IS=requireReason verður að vera true eða false.';
        RequireReasonNextLbl: Label 'Send requireReason as a JSON boolean, true or false.', Comment = 'is-IS=Sendu requireReason sem JSON-sanngildi, true eða false.';
        BlockedFormatErr: Label 'blockedDimensions must be an array of dimension codes.', Comment = 'is-IS=blockedDimensions verður að vera fylki af víddarkóðum.';
        BlockedFormatNextLbl: Label 'Send blockedDimensions as an array of strings, for example ["AREA"], or [] to clear the Bifrost list.', Comment = 'is-IS=Sendu blockedDimensions sem fylki af strengjum, til dæmis ["AREA"], eða [] til að hreinsa Bifröst-listann.';
        UnknownDimensionErr: Label 'The dimension %1 does not exist.', Comment = '%1 = the dimension code that was sent; is-IS=Víddin %1 er ekki til.';
        UnknownDimensionNextLbl: Label 'Use an existing dimension code from the Dimensions list (table Dimension), then send the whole list again. Nothing was changed.', Comment = 'is-IS=Notaðu fyrirliggjandi víddarkóða úr víddalistanum (tafla Dimension) og sendu síðan allan listann aftur. Engu var breytt.';
        DescriptionGetLbl: Label 'Reads the dimension correction setup: background threshold, reason requirement and blocked dimensions.', MaxLength = 250, Comment = 'is-IS=Les uppsetningu víddaleiðréttinga: mörk bakgrunnsvinnslu, kröfu um ástæðu og læstar víddir.';
        DescriptionSetLbl: Label 'Changes the dimension correction setup: background threshold, reason requirement and the Bifrost blocked dimensions.', MaxLength = 250, Comment = 'is-IS=Breytir uppsetningu víddaleiðréttinga: mörkum bakgrunnsvinnslu, kröfu um ástæðu og læstum víddum Bifröst.';
        NotesGetLbl: Label 'Without a saved setup the defaults are returned: backgroundThreshold 500 and requireReason true. blockedDimensions lists this app''s list with source "bifrost" and Microsoft''s Dimension Correction blocked setup with source "microsoft"; a code blocked in both lists appears once for each source. Nothing is written.', Comment = 'is-IS=Án vistaðrar uppsetningar eru sjálfgefin gildi skiluð: backgroundThreshold 500 og requireReason true. blockedDimensions sýnir lista þessa forrits með source "bifrost" og læstar víddir í víddaleiðréttingu Microsoft með source "microsoft"; kóði sem er læstur í báðum listum birtist einu sinni fyrir hvora uppsprettu. Engu er skrifað.';
        NotesSetLbl: Label 'Only the values sent are changed. blockedDimensions replaces the whole Bifrost list; Microsoft''s Dimension Correction blocked setup is never written. Every code is checked before anything is saved, so an unknown code changes nothing. Sending the same values again gives the same result. The response has the same shape as Dimensions.Setup.Get.', Comment = 'is-IS=Aðeins gildunum sem eru send er breytt. blockedDimensions kemur í stað alls Bifröst-listans; læstum víddum í víddaleiðréttingu Microsoft er aldrei breytt. Allir kóðar eru prófaðir áður en nokkuð er vistað, svo óþekktur kóði breytir engu. Sömu gildi send aftur gefa sömu niðurstöðu. Svarið er á sama formi og í Dimensions.Setup.Get.';

    /// <summary>Executes Dimensions.Setup.Get or Dimensions.Setup.Set and writes the response or a typed error.</summary>
    /// <param name="MessageType">Dimensions.Setup.Get or Dimensions.Setup.Set.</param>
    /// <param name="Argument">Request and response envelope.</param>
    procedure Execute(MessageType: Enum "Message Type ori"; var Argument: Record "Message Argument ori")
    var
        Request: JsonObject;
    begin
        if MessageType = MessageType::"Dimensions.Setup.Set" then begin
            Request := Argument.GetRequestJson();
            if not ApplySet(Request, Argument) then
                exit;
        end;
        Argument.SetResponseJson(BuildSetupResponse());
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>Builds the response shared by Get and Set: the current values and the union of blocked dimensions.</summary>
    /// <returns>The response object.</returns>
    procedure BuildSetupResponse() Response: JsonObject
    var
        Setup: Record "Dimension Corr. Setup ori";
        BlockedDim: Record "Dim. Corr. Blocked Dim. ori";
        MicrosoftBlocked: Record "Dim Correction Blocked Setup";
        Blocked: JsonArray;
    begin
        Setup.ReadIsolation := IsolationLevel::ReadCommitted;
        Setup.GetOrDefault();
        BlockedDim.ReadIsolation := IsolationLevel::ReadCommitted;
        if BlockedDim.FindSet() then
            repeat
                Blocked.Add(BlockedEntry(BlockedDim."Dimension Code", BifrostSourceTok));
            until BlockedDim.Next() = 0;
        MicrosoftBlocked.ReadIsolation := IsolationLevel::ReadCommitted;
        if MicrosoftBlocked.FindSet() then
            repeat
                Blocked.Add(BlockedEntry(MicrosoftBlocked."Dimension Code", MicrosoftSourceTok));
            until MicrosoftBlocked.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add(ThresholdKeyTok, Setup."Background Threshold");
        Response.Add(RequireReasonKeyTok, Setup."Require Reason");
        Response.Add(BlockedKeyTok, Blocked);
    end;

    local procedure BlockedEntry(DimensionCode: Code[20]; Source: Text) Entry: JsonObject
    begin
        Entry.Add('code', DimensionCode);
        Entry.Add('source', Source);
    end;

    local procedure ApplySet(Request: JsonObject; var Argument: Record "Message Argument ori"): Boolean
    var
        Setup: Record "Dimension Corr. Setup ori";
        TempNewBlocked: Record "Dim. Corr. Blocked Dim. ori" temporary;
        Token: JsonToken;
        Threshold: Integer;
        RequireReason: Boolean;
        HasThreshold: Boolean;
        HasRequireReason: Boolean;
        HasBlocked: Boolean;
    begin
        InitBounds();
        HasThreshold := Request.Get(ThresholdKeyTok, Token);
        if HasThreshold then
            if not ReadThreshold(Token, Threshold, Argument) then
                exit(false);
        HasRequireReason := Request.Get(RequireReasonKeyTok, Token);
        if HasRequireReason then
            if not ReadBooleanToken(Token, RequireReason) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, RequireReasonFormatErr, RequireReasonKeyTok, '', '', RequireReasonNextLbl);
                exit(false);
            end;
        HasBlocked := Request.Get(BlockedKeyTok, Token);
        if HasBlocked then
            if not ReadBlockedList(Token, TempNewBlocked, Argument) then
                exit(false);
        if not (HasThreshold or HasRequireReason or HasBlocked) then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::MissingParameter, NothingToSetErr, '', '', '', NothingToSetNextLbl);
            exit(false);
        end;

        // Every value is validated above; only now is anything written.
        if HasThreshold or HasRequireReason then begin
            if not Setup.Get() then begin
                Setup.Init();
                Setup.Insert();
            end;
            if HasThreshold then
                Setup."Background Threshold" := Threshold;
            if HasRequireReason then
                Setup."Require Reason" := RequireReason;
            Setup.Modify();
        end;
        if HasBlocked then
            ReplaceBlockedList(TempNewBlocked);
        exit(true);
    end;

    local procedure ReadThreshold(Token: JsonToken; var Threshold: Integer; var Argument: Record "Message Argument ori"): Boolean
    var
        DecimalValue: Decimal;
    begin
        if not ReadNumberToken(Token, DecimalValue) then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, ThresholdFormatErr, ThresholdKeyTok, '', '', ThresholdNextLbl);
            exit(false);
        end;
        if DecimalValue <> Round(DecimalValue, 1) then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, ThresholdFormatErr, ThresholdKeyTok, '', '', ThresholdNextLbl);
            exit(false);
        end;
        if (DecimalValue < MinThreshold) or (DecimalValue > MaxThreshold) then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ThresholdRangeErr, MinThreshold, MaxThreshold), ThresholdKeyTok, '', '', ThresholdNextLbl);
            exit(false);
        end;
        Threshold := DecimalValue;
        exit(true);
    end;

    local procedure ReadBlockedList(Token: JsonToken; var TempNewBlocked: Record "Dim. Corr. Blocked Dim. ori" temporary; var Argument: Record "Message Argument ori"): Boolean
    var
        Dimension: Record Dimension;
        Item: JsonToken;
        CodeText: Text;
    begin
        if not Token.IsArray() then begin
            Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, BlockedFormatErr, BlockedKeyTok, '', '', BlockedFormatNextLbl);
            exit(false);
        end;
        foreach Item in Token.AsArray() do begin
            if not ReadStringToken(Item, CodeText) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, BlockedFormatErr, BlockedKeyTok, '', '', BlockedFormatNextLbl);
                exit(false);
            end;
            CodeText := UpperCase(CodeText.Trim());
            if (CodeText = '') or (StrLen(CodeText) > MaxStrLen(Dimension.Code)) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownDimensionErr, CopyStr(CodeText, 1, 50)), BlockedKeyTok, '', '', UnknownDimensionNextLbl);
                exit(false);
            end;
            if not Dimension.Get(CopyStr(CodeText, 1, MaxStrLen(Dimension.Code))) then begin
                Argument.RespondWithError(Enum::"Bifrost Error Code ori"::RecordNotFound, StrSubstNo(UnknownDimensionErr, CodeText), BlockedKeyTok, '', '', UnknownDimensionNextLbl);
                exit(false);
            end;
            TempNewBlocked."Dimension Code" := Dimension.Code;
            if TempNewBlocked.Insert() then;
        end;
        exit(true);
    end;

    local procedure ReplaceBlockedList(var TempNewBlocked: Record "Dim. Corr. Blocked Dim. ori" temporary)
    var
        BlockedDim: Record "Dim. Corr. Blocked Dim. ori";
    begin
        if BlockedDim.FindSet() then
            repeat
                if not TempNewBlocked.Get(BlockedDim."Dimension Code") then
                    BlockedDim.Delete();
            until BlockedDim.Next() = 0;
        if TempNewBlocked.FindSet() then
            repeat
                if not BlockedDim.Get(TempNewBlocked."Dimension Code") then begin
                    BlockedDim."Dimension Code" := TempNewBlocked."Dimension Code";
                    BlockedDim.Insert();
                end;
            until TempNewBlocked.Next() = 0;
    end;

    local procedure ReadStringToken(Token: JsonToken; var Value: Text): Boolean
    var
        Serialized: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Serialized);
        if CopyStr(Serialized, 1, 1) <> '"' then
            exit(false);
        Value := Token.AsValue().AsText();
        exit(true);
    end;

    local procedure ReadNumberToken(Token: JsonToken; var Value: Decimal): Boolean
    var
        Serialized: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Token.WriteTo(Serialized);
        if (CopyStr(Serialized, 1, 1) = '"') or (Serialized in ['true', 'false']) then
            exit(false);
        Value := Token.AsValue().AsDecimal();
        exit(true);
    end;

    local procedure ReadBooleanToken(Token: JsonToken; var Value: Boolean): Boolean
    var
        Serialized: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Serialized);
        if not (Serialized in ['true', 'false']) then
            exit(false);
        Value := Serialized = 'true';
        exit(true);
    end;

    local procedure InitBounds()
    begin
        MinThreshold := 1;
        MaxThreshold := 100000;
    end;

    /// <summary>Returns the localized description.</summary>
    /// <param name="MessageType">The message type.</param>
    /// <returns>The description.</returns>
    procedure Description(MessageType: Enum "Message Type ori"): Text[250]
    begin
        if MessageType = MessageType::"Dimensions.Setup.Set" then
            exit(DescriptionSetLbl);
        exit(DescriptionGetLbl);
    end;

    /// <summary>Returns the localized notes chapter.</summary>
    /// <param name="MessageType">The message type.</param>
    /// <returns>The notes.</returns>
    procedure Notes(MessageType: Enum "Message Type ori"): Text
    begin
        if MessageType = MessageType::"Dimensions.Setup.Set" then
            exit(NotesSetLbl);
        exit(NotesGetLbl);
    end;

    /// <summary>Declares the queue envelope.</summary>
    /// <param name="MessageType">The message type.</param>
    /// <returns>The envelope chapter.</returns>
    procedure Envelope(MessageType: Enum "Message Type ori") Result: JsonObject
    var
        Subject: JsonObject;
        Forms: JsonArray;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('forms', Forms);
        Result.Add('subject', Subject);
        Result.Add('dataRequired', MessageType = MessageType::"Dimensions.Setup.Set");
        Result.Add('version', '1.0');
        Result.Add('contentType', 'text/json');
        Result.Add('endpoint', 'POST /queues');
    end;

    /// <summary>Declares the input values under data.</summary>
    /// <param name="MessageType">The message type.</param>
    /// <returns>The parameters chapter.</returns>
    procedure Parameters(MessageType: Enum "Message Type ori") Result: JsonArray
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
        Parameter: JsonObject;
    begin
        if MessageType <> MessageType::"Dimensions.Setup.Set" then
            exit;
        Parameter := Contracts.Parameter(ThresholdKeyTok, 'integer', false, 'Number of rows above which a correction runs in the background. Whole number from 1 to 100000. Omitted keeps the current value.');
        Parameter.Add('minimum', 1);
        Parameter.Add('maximum', 100000);
        Result.Add(Parameter);
        Result.Add(Contracts.Parameter(RequireReasonKeyTok, 'boolean', false, 'True when every correction must state a reason. Omitted keeps the current value.'));
        Result.Add(Contracts.Parameter(BlockedKeyTok, 'array', false, 'Dimension codes (strings) that corrections must not change. Replaces the whole Bifrost list; [] clears it. Every code must exist in the Dimension table. Microsoft''s Dimension Correction blocked setup is never written. Omitted keeps the current list.'));
    end;

    /// <summary>Declares the response fields shared by Get and Set.</summary>
    /// <returns>The response chapter.</returns>
    procedure Response() Result: JsonObject
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Children: JsonArray;
        ResponseField: JsonObject;
    begin
        Fields.Add(Contracts.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contracts.ResponseField(ThresholdKeyTok, 'integer', 'Rows above which a correction runs in the background. Default 500.'));
        Fields.Add(Contracts.ResponseField(RequireReasonKeyTok, 'boolean', 'True when a correction must state a reason. Default true.'));
        Children.Add(Contracts.ResponseField('code', 'string', 'Dimension code.'));
        Children.Add(Contracts.ResponseField('source', 'string', '"bifrost" for this app''s list, "microsoft" for Microsoft''s Dimension Correction blocked setup.'));
        ResponseField := Contracts.ResponseField(BlockedKeyTok, 'array', 'Union of both blocked lists. A code in both lists appears once per source.');
        ResponseField.Add('children', Children);
        Fields.Add(ResponseField);
        Result.Add('contentType', 'text/json');
        Result.Add('fields', Fields);
        Result.Add('whenEmpty', 'Success with the default values and an empty blockedDimensions array.');
    end;

    /// <summary>Declares typed errors with an actionable next step.</summary>
    /// <param name="MessageType">The message type.</param>
    /// <returns>The errors chapter.</returns>
    procedure Errors(MessageType: Enum "Message Type ori") Result: JsonArray
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType <> MessageType::"Dimensions.Setup.Set" then begin
            Result.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::PermissionDenied, 'The user cannot read the setup.', 'Assign the BIFROST DIMRead ori permission set.'));
            exit;
        end;
        Result.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::MissingParameter, 'No setup value was sent.', 'Send at least one of backgroundThreshold, requireReason or blockedDimensions.'));
        Result.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::InvalidParameterFormat, 'backgroundThreshold is not a whole number, requireReason is not a boolean, or blockedDimensions is not an array of strings.', 'Follow the parameters chapter for the JSON type of each value.'));
        Result.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::InvalidParameter, 'backgroundThreshold is below 1 or above 100000.', 'Send a whole number from 1 to 100000.'));
        Result.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::RecordNotFound, 'A code in blockedDimensions is not an existing dimension. Nothing is changed.', 'Use an existing dimension code and send the whole list again.'));
        Result.Add(Contracts.ErrorEntry(Enum::"Bifrost Error Code ori"::PermissionDenied, 'The user cannot change the setup.', 'Assign the BIFROST DIMFull ori permission set.'));
    end;

    /// <summary>Declares the effect of the call.</summary>
    /// <param name="MessageType">The message type.</param>
    /// <returns>The effect chapter.</returns>
    procedure Effect(MessageType: Enum "Message Type ori") Result: JsonObject
    begin
        if MessageType = MessageType::"Dimensions.Setup.Set" then begin
            Result.Add('effect', 'write');
            Result.Add('changes', 'Writes the dimension correction setup record and replaces this app''s blocked-dimension list when blockedDimensions is sent. Never writes Microsoft''s Dimension Correction blocked setup, entries or documents.');
            Result.Add('idempotent', true);
            Result.Add('permissionSet', 'BIFROST DIMFull ori');
            exit;
        end;
        Result.Add('effect', 'read');
        Result.Add('changes', 'No writes. Without a saved setup the defaults are returned and nothing is created.');
        Result.Add('idempotent', true);
        Result.Add('permissionSet', 'BIFROST DIMRead ori');
    end;

    /// <summary>Provides fictitious, executable queue examples.</summary>
    /// <param name="MessageType">The message type.</param>
    /// <returns>The examples chapter.</returns>
    procedure Examples(MessageType: Enum "Message Type ori") Result: JsonArray
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
    begin
        if MessageType = MessageType::"Dimensions.Setup.Set" then begin
            Result.Add(Contracts.Example('Change the threshold and the blocked list', '{"type":"Dimensions.Setup.Set","data":{"backgroundThreshold":1000,"requireReason":true,"blockedDimensions":["AREA"]}}', '{"status":"Success","backgroundThreshold":1000,"requireReason":true,"blockedDimensions":[{"code":"AREA","source":"bifrost"}]}'));
            Result.Add(Contracts.Example('Clear the Bifrost blocked list', '{"type":"Dimensions.Setup.Set","data":{"blockedDimensions":[]}}', '{"status":"Success","backgroundThreshold":1000,"requireReason":true,"blockedDimensions":[]}'));
            exit;
        end;
        Result.Add(Contracts.Example('Read the setup before any change', '{"type":"Dimensions.Setup.Get","data":{}}', '{"status":"Success","backgroundThreshold":500,"requireReason":true,"blockedDimensions":[]}'));
        Result.Add(Contracts.Example('Read a setup with both blocked lists', '{"type":"Dimensions.Setup.Get","data":{}}', '{"status":"Success","backgroundThreshold":1000,"requireReason":false,"blockedDimensions":[{"code":"AREA","source":"bifrost"},{"code":"SALESCAMPAIGN","source":"microsoft"}]}'));
    end;
}
