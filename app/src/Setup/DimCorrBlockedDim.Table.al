namespace Origo.Bifrost.Dimensions;

using Microsoft.Finance.Dimension;

/// <summary>
/// Dimensions that Bifrost Dimensions must not correct, in addition to Microsoft's own Dimension Correction blocked setup.
/// Maintained only through the Dimensions.Setup.Set message type, which replaces the whole list.
/// </summary>
table 10076496 "Dim. Corr. Blocked Dim. ori"
{
    Caption = 'Dimension Correction Blocked Dimension', Comment = 'is-IS=Læst vídd í víddaleiðréttingu';
    DataClassification = CustomerContent;
    Access = Internal;
    Extensible = false;

    fields
    {
        field(1; "Dimension Code"; Code[20])
        {
            Caption = 'Dimension Code', Comment = 'is-IS=Víddarkóði';
            ToolTip = 'Specifies a dimension that dimension corrections must not change.', Comment = 'is-IS=Tilgreinir vídd sem víddaleiðréttingar mega ekki breyta.';
            NotBlank = true;
            TableRelation = Dimension.Code;
        }
    }

    keys
    {
        key(PK; "Dimension Code")
        {
            Clustered = true;
        }
    }
}
