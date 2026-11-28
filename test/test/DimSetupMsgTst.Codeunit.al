namespace Origo.Bifrost.Dimensions.Test;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.Dimension.Correction;
using Origo.Bifrost;
using Origo.Bifrost.Dimensions;
using System.Globalization;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Story D6 (#2): Dimensions.Setup.Get and Dimensions.Setup.Set through public dispatch, in LCID 1033 and 1039.
/// Covers defaults on the first Get, a Set + Get round trip, idempotency, an unknown dimension refused,
/// a Microsoft-blocked dimension reported with source microsoft, threshold bounds, invalid input and permissions.
/// </summary>
codeunit 98320 "Dim Setup Msg Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        OriginalLanguage: Integer;
        OriginalDefaultLanguage: Text;

    /// <summary>AC6 defaults on the first Get, LCID 1033.</summary>
    [Test]
    procedure Defaults_1033()
    begin
        Initialize(1033);
        VerifyDefaults();
        Cleanup();
    end;

    /// <summary>AC6 defaults on the first Get, LCID 1039.</summary>
    [Test]
    procedure Defaults_1039()
    begin
        Initialize(1039);
        VerifyDefaults();
        Cleanup();
    end;

    /// <summary>AC6 Set + Get round trip and idempotency, LCID 1033.</summary>
    [Test]
    procedure RoundTrip_1033()
    begin
        Initialize(1033);
        VerifyRoundTrip();
        Cleanup();
    end;

    /// <summary>AC6 Set + Get round trip and idempotency, LCID 1039.</summary>
    [Test]
    procedure RoundTrip_1039()
    begin
        Initialize(1039);
        VerifyRoundTrip();
        Cleanup();
    end;

    /// <summary>AC3/AC6 unknown dimension refused with nextStep and nothing changed, LCID 1033.</summary>
    [Test]
    procedure UnknownDimension_1033()
    begin
        Initialize(1033);
        VerifyUnknownDimension('The dimension');
        Cleanup();
    end;

    /// <summary>AC3/AC6 unknown dimension refused with nextStep and nothing changed, LCID 1039.</summary>
    [Test]
    procedure UnknownDimension_1039()
    begin
        Initialize(1039);
        VerifyUnknownDimension('Víddin');
        Cleanup();
    end;

    /// <summary>AC2/AC3/AC6 Microsoft-blocked dimension has source microsoft and is never written, LCID 1033.</summary>
    [Test]
    procedure MicrosoftBlocked_1033()
    begin
        Initialize(1033);
        VerifyMicrosoftBlocked();
        Cleanup();
    end;

    /// <summary>AC2/AC3/AC6 Microsoft-blocked dimension has source microsoft and is never written, LCID 1039.</summary>
    [Test]
    procedure MicrosoftBlocked_1039()
    begin
        Initialize(1039);
        VerifyMicrosoftBlocked();
        Cleanup();
    end;

    /// <summary>AC3/AC6 threshold bounds 1 and 100000 accepted, 0 and 100001 refused, LCID 1033.</summary>
    [Test]
    procedure ThresholdBounds_1033()
    begin
        Initialize(1033);
        VerifyThresholdBounds();
        Cleanup();
    end;

    /// <summary>AC3/AC6 threshold bounds 1 and 100000 accepted, 0 and 100001 refused, LCID 1039.</summary>
    [Test]
    procedure ThresholdBounds_1039()
    begin
        Initialize(1039);
        VerifyThresholdBounds();
        Cleanup();
    end;

    /// <summary>Invalid JSON types and an empty Set are refused with typed errors, LCID 1033.</summary>
    [Test]
    procedure InvalidInput_1033()
    begin
        Initialize(1033);
        VerifyInvalidInput();
        Cleanup();
    end;

    /// <summary>Invalid JSON types and an empty Set are refused with typed errors, LCID 1039.</summary>
    [Test]
    procedure InvalidInput_1039()
    begin
        Initialize(1039);
        VerifyInvalidInput();
        Cleanup();
    end;

    /// <summary>AC5 contracts and localized help, LCID 1033.</summary>
    [Test]
    procedure Contracts_1033()
    begin
        Initialize(1033);
        VerifyContracts('dimension');
        Cleanup();
    end;

    /// <summary>AC5 contracts and localized help, LCID 1039.</summary>
    [Test]
    procedure Contracts_1039()
    begin
        Initialize(1039);
        VerifyContracts('vídd');
        Cleanup();
    end;

    /// <summary>AC4 Get is in the Read set and Set in the Full set.</summary>
    [Test]
    procedure Permissions_ReadAndFull()
    var
        Setup: Record "Dimension Corr. Setup ori";
        BlockedDim: Record "Dim. Corr. Blocked Dim. ori";
        MicrosoftBlocked: Record "Dim Correction Blocked Setup";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        SetupMessages: Codeunit "Dim Setup Msg Mgt ori";
        GetType: Interface "Msg Interface ori";
        SetType: Interface "Msg Interface ori";
        ReadCanRead: Boolean;
        ReadReply: JsonObject;
        ReadCanWrite: Boolean;
        ReadGetEnabled: Boolean;
        ReadSetEnabled: Boolean;
        FullCanWrite: Boolean;
        FullCanWriteMicrosoft: Boolean;
        FullSetEnabled: Boolean;
    begin
        // [GIVEN] The two setup message types
        GetType := Enum::"Message Type ori"::"Dimensions.Setup.Get";
        SetType := Enum::"Message Type ori"::"Dimensions.Setup.Set";

        // [WHEN] Only the Read set is assigned, then only the Full set
        LowerPermissions.SetExactPermissionSet('BIFROST DIMRead ori');
        ReadCanRead := Setup.ReadPermission() and BlockedDim.ReadPermission();
        ReadReply := SetupMessages.BuildSetupResponse();
        ReadCanWrite := Setup.WritePermission() or BlockedDim.WritePermission();
        ReadGetEnabled := GetType.IsEnabled();
        ReadSetEnabled := SetType.IsEnabled();
        LowerPermissions.SetExactPermissionSet('BIFROST DIMFull ori');
        FullCanWrite := Setup.WritePermission() and BlockedDim.WritePermission();
        FullCanWriteMicrosoft := MicrosoftBlocked.WritePermission();
        FullSetEnabled := SetType.IsEnabled();
        LowerPermissions.SetOutsideO365Scope();

        // [THEN] Read can read both lists through the management codeunit and runs only Get; Full can also write this app's setup, never Microsoft's list
        Assert.IsTrue(ReadCanRead, 'The Read set must read the setup and the Bifrost list.');
        AssertSuccess(ReadReply);
        Assert.IsFalse(ReadCanWrite, 'The Read set must not write the setup.');
        Assert.IsTrue(ReadGetEnabled, 'Dimensions.Setup.Get is enabled for the Read set.');
        Assert.IsFalse(ReadSetEnabled, 'Dimensions.Setup.Set is not enabled for the Read set.');
        Assert.IsTrue(FullCanWrite, 'The Full set must write the setup and the Bifrost list.');
        Assert.IsFalse(FullCanWriteMicrosoft, 'The Full set must not write Microsoft''s blocked setup.');
        Assert.IsTrue(FullSetEnabled, 'Dimensions.Setup.Set is enabled for the Full set.');
    end;

    local procedure VerifyDefaults()
    var
        Setup: Record "Dimension Corr. Setup ori";
        Reply: JsonObject;
    begin
        // [GIVEN] No saved setup and no blocked dimensions in either list (Initialize)
        // [WHEN] The setup is read
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Get", '{}');

        // [THEN] The defaults are returned and nothing is created
        AssertSuccess(Reply);
        Assert.AreEqual(500, Reply.GetInteger('backgroundThreshold'), 'Default background threshold');
        Assert.IsTrue(Reply.GetBoolean('requireReason'), 'Default require reason');
        Assert.AreEqual(0, Reply.GetArray('blockedDimensions').Count(), 'No blocked dimensions by default');
        Assert.IsTrue(Setup.IsEmpty(), 'A read must not create the setup record.');
    end;

    local procedure VerifyRoundTrip()
    var
        BlockedDim: Record "Dim. Corr. Blocked Dim. ori";
        Reply: JsonObject;
        FirstCode: Code[20];
        SecondCode: Code[20];
        Body: Text;
    begin
        // [GIVEN] Two existing dimensions, one already in the Bifrost list
        GetTwoDimensions(FirstCode, SecondCode);
        BlockedDim."Dimension Code" := FirstCode;
        BlockedDim.Insert();
        Body := '{"backgroundThreshold":1234,"requireReason":false,"blockedDimensions":["' + LowerCase(SecondCode) + '"]}';

        // [WHEN] Set replaces the values and the list, twice with the same body
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", Body);
        AssertSuccess(Reply);
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", Body);
        AssertSuccess(Reply);
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Get", '{}');

        // [THEN] Get returns exactly what was set; the earlier code is gone and nothing is duplicated
        AssertSuccess(Reply);
        Assert.AreEqual(1234, Reply.GetInteger('backgroundThreshold'), 'Threshold round trip');
        Assert.IsFalse(Reply.GetBoolean('requireReason'), 'Require reason round trip');
        Assert.AreEqual(1, Reply.GetArray('blockedDimensions').Count(), 'Full replacement, no duplicates');
        AssertBlocked(Reply, SecondCode, 'bifrost');
        Assert.AreEqual(1, BlockedDim.Count(), 'Exactly one Bifrost row after an idempotent Set');

        // [WHEN] Only requireReason is sent
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"requireReason":true}');

        // [THEN] The other values are kept
        AssertSuccess(Reply);
        Assert.AreEqual(1234, Reply.GetInteger('backgroundThreshold'), 'Threshold kept when omitted');
        Assert.IsTrue(Reply.GetBoolean('requireReason'), 'Require reason changed');
        Assert.AreEqual(1, Reply.GetArray('blockedDimensions').Count(), 'List kept when omitted');

        // [WHEN] An empty list is sent
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"blockedDimensions":[]}');

        // [THEN] The Bifrost list is cleared
        AssertSuccess(Reply);
        Assert.AreEqual(0, Reply.GetArray('blockedDimensions').Count(), 'Empty list clears the Bifrost list');
        Assert.IsTrue(BlockedDim.IsEmpty(), 'No Bifrost rows left');
    end;

    local procedure VerifyUnknownDimension(ExpectedMessageStart: Text)
    var
        Setup: Record "Dimension Corr. Setup ori";
        BlockedDim: Record "Dim. Corr. Blocked Dim. ori";
        Reply: JsonObject;
        FirstCode: Code[20];
        SecondCode: Code[20];
    begin
        // [GIVEN] A Bifrost list with one existing dimension
        GetTwoDimensions(FirstCode, SecondCode);
        BlockedDim."Dimension Code" := FirstCode;
        BlockedDim.Insert();

        // [WHEN] Set sends a valid threshold, a valid code and an unknown code
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"backgroundThreshold":900,"blockedDimensions":["' + SecondCode + '","XDIMUNKNOWN"]}');

        // [THEN] It is refused with RecordNotFound and a localized nextStep, and nothing is changed
        AssertProblem(Reply, 'RecordNotFound');
        Assert.IsTrue(Format(Reply).Contains(ExpectedMessageStart), 'Localized refusal: ' + Format(Reply));
        Assert.IsTrue(Format(Reply).Contains('XDIMUNKNOWN'), 'The refusal names the unknown code');
        Assert.IsTrue(Setup.IsEmpty(), 'The threshold must not be saved when the list is refused.');
        Assert.AreEqual(1, BlockedDim.Count(), 'The Bifrost list is unchanged');
        Assert.IsTrue(BlockedDim.Get(FirstCode), 'The original code is kept');

        // [WHEN] A code longer than a dimension code is sent
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"blockedDimensions":["XDIMCODEMUCHLONGERTHANTWENTY"]}');

        // [THEN] It is refused the same way
        AssertProblem(Reply, 'RecordNotFound');
        Assert.AreEqual(1, BlockedDim.Count(), 'The Bifrost list is still unchanged');
    end;

    local procedure VerifyMicrosoftBlocked()
    var
        BlockedDim: Record "Dim. Corr. Blocked Dim. ori";
        MicrosoftBlocked: Record "Dim Correction Blocked Setup";
        Reply: JsonObject;
        FirstCode: Code[20];
        SecondCode: Code[20];
    begin
        // [GIVEN] One dimension blocked in Microsoft's setup and the same plus another in the Bifrost list
        GetTwoDimensions(FirstCode, SecondCode);
        MicrosoftBlocked."Dimension Code" := SecondCode;
        MicrosoftBlocked.Insert();
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"blockedDimensions":["' + FirstCode + '","' + SecondCode + '"]}');
        AssertSuccess(Reply);

        // [WHEN] The setup is read
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Get", '{}');

        // [THEN] The union carries each code with its source
        AssertSuccess(Reply);
        Assert.AreEqual(3, Reply.GetArray('blockedDimensions').Count(), 'Two Bifrost rows and one Microsoft row');
        AssertBlocked(Reply, FirstCode, 'bifrost');
        AssertBlocked(Reply, SecondCode, 'bifrost');
        AssertBlocked(Reply, SecondCode, 'microsoft');

        // [WHEN] The Bifrost list is cleared
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"blockedDimensions":[]}');

        // [THEN] Microsoft's list is untouched and still reported
        AssertSuccess(Reply);
        Assert.AreEqual(1, Reply.GetArray('blockedDimensions').Count(), 'Only the Microsoft row is left');
        AssertBlocked(Reply, SecondCode, 'microsoft');
        Assert.IsTrue(MicrosoftBlocked.Get(SecondCode), 'Microsoft''s blocked setup is never written');
        Assert.IsTrue(BlockedDim.IsEmpty(), 'The Bifrost list is empty');
    end;

    local procedure VerifyThresholdBounds()
    var
        Reply: JsonObject;
    begin
        // [WHEN] The lowest and highest allowed values are sent
        // [THEN] Both are accepted
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"backgroundThreshold":1}');
        AssertSuccess(Reply);
        Assert.AreEqual(1, Reply.GetInteger('backgroundThreshold'), 'Lower bound accepted');
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"backgroundThreshold":100000}');
        AssertSuccess(Reply);
        Assert.AreEqual(100000, Reply.GetInteger('backgroundThreshold'), 'Upper bound accepted');

        // [WHEN] Values just outside the bounds are sent
        // [THEN] Both are refused and the saved value is kept
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"backgroundThreshold":0}'), 'InvalidParameter');
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"backgroundThreshold":100001}'), 'InvalidParameter');
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"backgroundThreshold":-5}'), 'InvalidParameter');
        Reply := Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Get", '{}');
        Assert.AreEqual(100000, Reply.GetInteger('backgroundThreshold'), 'Refused values do not change the setup');
    end;

    local procedure VerifyInvalidInput()
    var
        Setup: Record "Dimension Corr. Setup ori";
    begin
        // [WHEN] Wrong JSON types or no values are sent
        // [THEN] Each is refused with a typed error and nextStep, and nothing is saved
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"backgroundThreshold":"500"}'), 'InvalidParameterFormat');
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"backgroundThreshold":12.5}'), 'InvalidParameterFormat');
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"backgroundThreshold":1e40,"requireReason":false}'), 'InvalidParameterFormat');
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"backgroundThreshold":-1e40}'), 'InvalidParameterFormat');
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"requireReason":"yes"}'), 'InvalidParameterFormat');
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"blockedDimensions":"AREA"}'), 'InvalidParameterFormat');
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{"blockedDimensions":[1]}'), 'InvalidParameterFormat');
        AssertProblem(Invoke(Enum::"Message Type ori"::"Dimensions.Setup.Set", '{}'), 'MissingParameter');
        Assert.IsTrue(Setup.IsEmpty(), 'Refused requests save nothing');
    end;

    local procedure VerifyContracts(ExpectedWord: Text)
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
        MessageType: Enum "Message Type ori";
        Implementation: Interface "Msg Interface ori";
        Discovery: Interface "Msg Discovery ori";
        Contract: JsonObject;
        Token: JsonToken;
        Ordinal: Integer;
    begin
        for Ordinal := 10076495 to 10076496 do begin
            MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
            Implementation := MessageType;
            Discovery := MessageType;
            Assert.IsTrue(LowerCase(Implementation.GetDescription()).Contains(ExpectedWord), 'Localized description: ' + Implementation.GetDescription());
            Assert.IsTrue(LowerCase(Discovery.GetKeywords()).Contains(ExpectedWord), 'Localized keywords: ' + Discovery.GetKeywords());
            Contracts.GetContract(MessageType, Contract);
            Assert.IsTrue(Contract.Get('parameters', Token), 'Parameters chapter');
            Assert.IsTrue(Contract.Get('response', Token), 'Response chapter');
            Assert.IsTrue(Contract.Get('errors', Token), 'Errors chapter');
            Assert.IsTrue(Contract.Get('examples', Token), 'Examples chapter');
            Assert.AreEqual('POST /queues', Contract.GetObject('envelope').GetText('endpoint'), 'Queued contract');
            if MessageType = MessageType::"Dimensions.Setup.Get" then begin
                Assert.AreEqual(Enum::"Msg Direction ori"::Outbound, Implementation.GetMessageDirection(), 'Get reads');
                Assert.AreEqual('read', Contract.GetObject('effect').GetText('effect'), 'Read effect');
            end else begin
                Assert.AreEqual(Enum::"Msg Direction ori"::Inbound, Implementation.GetMessageDirection(), 'Set writes');
                Assert.AreEqual('write', Contract.GetObject('effect').GetText('effect'), 'Write effect');
                Assert.AreEqual(3, Contract.GetArray('parameters').Count(), 'Three Set parameters');
            end;
            Clear(Contract);
        end;
    end;

    local procedure GetTwoDimensions(var FirstCode: Code[20]; var SecondCode: Code[20])
    var
        Dimension: Record Dimension;
    begin
        Dimension.FindSet();
        FirstCode := Dimension.Code;
        Dimension.Next();
        SecondCode := Dimension.Code;
        Assert.AreNotEqual(FirstCode, SecondCode, 'The demo company needs two dimensions.');
    end;

    local procedure AssertBlocked(Reply: JsonObject; DimensionCode: Code[20]; Source: Text)
    var
        Item: JsonToken;
    begin
        foreach Item in Reply.GetArray('blockedDimensions') do
            if (Item.AsObject().GetText('code') = DimensionCode) and (Item.AsObject().GetText('source') = Source) then
                exit;
        Assert.Fail(StrSubstNo('%1 with source %2 is missing: %3', DimensionCode, Source, Format(Reply)));
    end;

    local procedure Invoke(MessageType: Enum "Message Type ori"; Body: Text) Reply: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        Request: BigText;
        Response: BigText;
        ResponseType: Text[100];
        TextResponse: Text;
    begin
        Request.AddText(Body);
        Dispatcher.Execute(MessageType, Enum::"Message Version ori"::"1.0", '', '', 'application/json', Request, Response, ResponseType, true);
        Response.GetSubText(TextResponse, 1);
        Assert.IsTrue(Reply.ReadFrom(TextResponse), 'Structured dispatch response: ' + TextResponse);
    end;

    local procedure AssertSuccess(Reply: JsonObject)
    begin
        Assert.AreEqual('Success', Reply.GetText('status'), 'Call succeeded: ' + Format(Reply));
        Assert.IsFalse(Reply.Contains('warnings'), 'Valid request has no parameter warnings: ' + Format(Reply));
    end;

    local procedure AssertProblem(Reply: JsonObject; ExpectedCode: Text)
    begin
        Assert.AreEqual('Error', Reply.GetText('status'), 'Refusal: ' + Format(Reply));
        Assert.AreEqual(ExpectedCode, Reply.GetText('code'), 'Typed code: ' + Format(Reply));
        Assert.IsTrue(Reply.GetText('nextStep') <> '', 'Actionable next step');
    end;

    local procedure Initialize(NewLanguageId: Integer)
    var
        Setup: Record "Setup ori";
        Language: Record Language;
        SetupRef: RecordRef;
        LanguageField: FieldRef;
    begin
        OriginalLanguage := GlobalLanguage();
        Setup.GetRecordOnce();
        SetupRef.GetTable(Setup);
        LanguageField := SetupRef.Field(14);
        OriginalDefaultLanguage := Format(LanguageField.Value);
        Language.SetRange("Windows Language ID", NewLanguageId);
        Language.FindFirst();
        LanguageField.Value := Language.Code;
        SetupRef.Modify();
        GlobalLanguage(NewLanguageId);
        DeleteFixture();
    end;

    local procedure Cleanup()
    var
        Setup: Record "Setup ori";
        SetupRef: RecordRef;
        LanguageField: FieldRef;
    begin
        DeleteFixture();
        Setup.GetRecordOnce();
        SetupRef.GetTable(Setup);
        LanguageField := SetupRef.Field(14);
        LanguageField.Value := OriginalDefaultLanguage;
        SetupRef.Modify();
        GlobalLanguage(OriginalLanguage);
    end;

    local procedure DeleteFixture()
    var
        Setup: Record "Dimension Corr. Setup ori";
        BlockedDim: Record "Dim. Corr. Blocked Dim. ori";
        MicrosoftBlocked: Record "Dim Correction Blocked Setup";
    begin
        Setup.DeleteAll();
        BlockedDim.DeleteAll();
        MicrosoftBlocked.DeleteAll();
    end;
}
