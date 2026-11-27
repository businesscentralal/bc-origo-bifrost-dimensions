namespace Origo.Bifrost.Dimensions;

using Origo.Bifrost;

/// <summary>Reads the dimension correction setup and the union of blocked dimensions.</summary>
codeunit 10076497 "Dim Setup Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        SetupMsgMgt: Codeunit "Dim Setup Msg Mgt ori";

    /// <summary>Reports availability for users who may read the setup.</summary>
    /// <returns>True when the user has the required permission.</returns>
    procedure IsEnabled(): Boolean
    var
        Setup: Record "Dimension Corr. Setup ori";
    begin
        exit(Setup.ReadPermission());
    end;

    /// <summary>No Foundation record filter is used.</summary>
    /// <returns>Zero.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>Returns the localized description.</summary>
    /// <returns>The description.</returns>
    procedure GetDescription(): Text[250]
    begin
        exit(SetupMsgMgt.Description(Enum::"Message Type ori"::"Dimensions.Setup.Get"));
    end;

    /// <summary>Declares the message direction.</summary>
    /// <returns>The direction.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Returns the localized search keywords.</summary>
    /// <returns>The keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'dimension correction setup, read dimension settings, blocked dimensions, background threshold, require reason', Comment = 'is-IS=uppsetning víddaleiðréttinga, lesa víddastillingar, læstar víddir, mörk bakgrunnsvinnslu, krefjast ástæðu, víddir, leiðrétta víddir';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns the localized selection help.</summary>
    /// <returns>The selection description.</returns>
    procedure GetSelectionDescription(): Text
    begin
        exit(SetupMsgMgt.Description(Enum::"Message Type ori"::"Dimensions.Setup.Get"));
    end;

    /// <summary>Runs the licensed request through the shared setup handler.</summary>
    /// <param name="Argument">Request and response envelope.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        SetupMsgMgt.Execute(Enum::"Message Type ori"::"Dimensions.Setup.Get", Argument);
    end;

    /// <summary>Returns the envelope contract chapter.</summary>
    /// <param name="Envelope">Receives the chapter.</param>
    /// <returns>True.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Envelope := SetupMsgMgt.Envelope(Enum::"Message Type ori"::"Dimensions.Setup.Get");
        exit(true);
    end;

    /// <summary>No target chapter: the setup is per company.</summary>
    /// <param name="Target">Unused.</param>
    /// <returns>False.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the parameters contract chapter.</summary>
    /// <param name="Parameters">Receives the chapter.</param>
    /// <returns>True.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters := SetupMsgMgt.Parameters(Enum::"Message Type ori"::"Dimensions.Setup.Get");
        exit(true);
    end;

    /// <summary>Returns the response contract chapter.</summary>
    /// <param name="Response">Receives the chapter.</param>
    /// <returns>True.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Response := SetupMsgMgt.Response();
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter.</summary>
    /// <param name="Errors">Receives the chapter.</param>
    /// <returns>True.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Errors := SetupMsgMgt.Errors(Enum::"Message Type ori"::"Dimensions.Setup.Get");
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter.</summary>
    /// <param name="Effect">Receives the chapter.</param>
    /// <returns>True.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect := SetupMsgMgt.Effect(Enum::"Message Type ori"::"Dimensions.Setup.Get");
        exit(true);
    end;

    /// <summary>Foundation supplies the metering chapter.</summary>
    /// <param name="Metering">Unused.</param>
    /// <returns>False.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the related contract chapter.</summary>
    /// <param name="Related">Receives the chapter.</param>
    /// <returns>True.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contracts: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contracts.RelatedEntry('Dimensions.Setup.Set', 'To change the values or the Bifrost blocked list.'));
        exit(true);
    end;

    /// <summary>No workflow chapter.</summary>
    /// <param name="Workflow">Unused.</param>
    /// <returns>False.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the examples contract chapter.</summary>
    /// <param name="Examples">Receives the chapter.</param>
    /// <returns>True.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Examples := SetupMsgMgt.Examples(Enum::"Message Type ori"::"Dimensions.Setup.Get");
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter.</summary>
    /// <param name="Overview">Receives the chapter.</param>
    /// <returns>True.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := SetupMsgMgt.Description(Enum::"Message Type ori"::"Dimensions.Setup.Get");
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter.</summary>
    /// <param name="Notes">Receives the chapter.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := SetupMsgMgt.Notes(Enum::"Message Type ori"::"Dimensions.Setup.Get");
        exit(true);
    end;
}
