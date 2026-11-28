namespace Origo.Bifrost.Dimensions;

using Origo.Bifrost;

/// <summary>
/// Registers the Bifrost Dimensions message contracts with Foundation. Keys are the published API contract and are never renamed.
/// </summary>
enumextension 10076491 "Dimensions Message Type ori" extends "Message Type ori"
{
    /// <summary>Reads the dimension correction setup and the union of blocked dimensions.</summary>
    value(10076495; "Dimensions.Setup.Get")
    {
        Caption = 'Dimensions.Setup.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Dim Setup Get Impl ori", "Msg Discovery ori" = "Dim Setup Get Impl ori", "Msg Contract ori" = "Dim Setup Get Impl ori";
    }
    /// <summary>Changes the dimension correction setup and replaces the Bifrost blocked-dimension list.</summary>
    value(10076496; "Dimensions.Setup.Set")
    {
        Caption = 'Dimensions.Setup.Set', Locked = true;
        Implementation = "Msg Interface ori" = "Dim Setup Set Impl ori", "Msg Discovery ori" = "Dim Setup Set Impl ori", "Msg Contract ori" = "Dim Setup Set Impl ori";
    }
    /// <summary>Finds posted ledger entries and posted documents by what they are and by their current dimensions.</summary>
    value(10076492; "Dimensions.Entries.Find")
    {
        Caption = 'Dimensions.Entries.Find', Locked = true;
        Implementation = "Msg Interface ori" = "Dimensions Find Impl ori", "Msg Discovery ori" = "Dimensions Find Impl ori", "Msg Contract ori" = "Dimensions Find Impl ori";
    }
    /// <summary>Previews a dimension correction: cascade, validation, new dimension sets and a preview token. Nothing is corrected.</summary>
    value(10076500; "Dimensions.Correction.Preview")
    {
        Caption = 'Dimensions.Correction.Preview', Locked = true;
        Implementation = "Msg Interface ori" = "Dim Corr Preview Impl ori", "Msg Discovery ori" = "Dim Corr Preview Impl ori", "Msg Contract ori" = "Dim Corr Preview Impl ori";
    }
}
