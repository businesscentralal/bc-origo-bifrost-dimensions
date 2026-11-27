namespace Origo.Bifrost.Dimensions;

using Microsoft.Finance.Dimension;

/// <summary>
/// Full Bifrost Dimensions role. Includes the read role; grants Dimensions.Setup.Set, which writes only this app's setup and blocked list.
/// </summary>
permissionset 10076487 "BIFROST DIMFull ori"
{
    Assignable = true;
    Access = Public;
    Caption = 'Bifrost Dimensions Full', MaxLength = 30, Comment = 'is-IS=Bifröst - víddir (fullt)';
    IncludedPermissionSets = "BIFROST DIMRead ori";
    Permissions =
        tabledata "Dimension Corr. Setup ori" = RIMD,
        tabledata "Dim. Corr. Blocked Dim. ori" = RIMD,
        tabledata Dimension = R,
        codeunit "Dim Setup Set Impl ori" = X;
}
