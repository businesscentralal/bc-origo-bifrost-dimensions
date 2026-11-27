namespace Origo.Bifrost.Dimensions;

using Origo.Bifrost;

/// <summary>
/// Registers the Bifrost Dimensions message contracts with Foundation.
/// </summary>
enumextension 10076491 "Dimensions Message Type ori" extends "Message Type ori"
{
    /// <summary>Finds posted ledger entries and posted documents by what they are and by their current dimensions.</summary>
    value(10076492; "Dimensions.Entries.Find")
    {
        Caption = 'Dimensions.Entries.Find', Locked = true;
        Implementation = "Msg Interface ori" = "Dimensions Find Impl ori", "Msg Discovery ori" = "Dimensions Find Impl ori", "Msg Contract ori" = "Dimensions Find Impl ori";
    }
}
