namespace Origo.Bifrost.Dimensions;

/// <summary>
/// Per-company setup that the Bifrost Dimensions correction engine reads. There is one record with an empty key.
/// It is maintained only through the Dimensions.Setup.Get and Dimensions.Setup.Set message types; there is no page.
/// </summary>
table 10076495 "Dimension Corr. Setup ori"
{
    Caption = 'Dimension Correction Setup', Comment = 'is-IS=Uppsetning víddaleiðréttinga';
    DataClassification = CustomerContent;
    Access = Internal;
    Extensible = false;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            AllowInCustomizations = Never;
        }
        field(2; "Background Threshold"; Integer)
        {
            Caption = 'Background Threshold', Comment = 'is-IS=Mörk bakgrunnsvinnslu';
            ToolTip = 'Specifies the number of rows above which a dimension correction runs in the background.', Comment = 'is-IS=Tilgreinir fjölda lína sem víddaleiðrétting þarf að fara yfir til að keyra í bakgrunni.';
            InitValue = 500;
            MinValue = 1;
            MaxValue = 100000;
        }
        field(3; "Require Reason"; Boolean)
        {
            Caption = 'Require Reason', Comment = 'is-IS=Krefjast ástæðu';
            ToolTip = 'Specifies whether a dimension correction must state a reason.', Comment = 'is-IS=Tilgreinir hvort víddaleiðrétting þurfi að tilgreina ástæðu.';
            InitValue = true;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    /// <summary>
    /// Reads the setup record, or the default values when none has been saved yet. Never writes.
    /// </summary>
    /// <returns>True when a saved record exists; false when the defaults are returned.</returns>
    procedure GetOrDefault(): Boolean
    begin
        if Rec.Get() then
            exit(true);
        Rec.Init();
        exit(false);
    end;
}
