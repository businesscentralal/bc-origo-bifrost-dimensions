namespace Origo.Bifrost.Dimensions;

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
        table "Dimension Corr. Setup ori" = X,
        table "Dim. Corr. Blocked Dim. ori" = X,
        codeunit "Dim Setup Get Impl ori" = X,
        codeunit "Dim Setup Msg Mgt ori" = X,
        codeunit "Dim Corr Preview Impl ori" = X,
        codeunit "Dim Corr. Engine ori" = X;
}
