namespace Origo.Bifrost.Dimensions;

using Microsoft.Finance.Dimension.Correction;

/// <summary>
/// Read-only Bifrost Dimensions role. Grants Dimensions.Setup.Get: read access to both blocked lists, never write.
/// </summary>
permissionset 10076488 "BIFROST DIMRead ori"
{
    Assignable = true;
    Access = Public;
    Caption = 'Bifrost Dimensions Read', MaxLength = 30, Comment = 'is-IS=Bifröst - víddir (lestur)';
    IncludedPermissionSets = "BIFROST DIM ori";
    Permissions =
        tabledata "Dimension Corr. Setup ori" = R,
        tabledata "Dim. Corr. Blocked Dim. ori" = R,
        tabledata "Dim Correction Blocked Setup" = R,
        table "Dimension Corr. Setup ori" = X,
        table "Dim. Corr. Blocked Dim. ori" = X,
        codeunit "Dim Setup Get Impl ori" = X,
        codeunit "Dim Setup Msg Mgt ori" = X;
}
