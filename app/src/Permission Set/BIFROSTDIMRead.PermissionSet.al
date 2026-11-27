namespace Origo.Bifrost.Dimensions;

/// <summary>
/// Read-only Bifrost Dimensions role. Message types add their read permissions here as they are built.
/// </summary>
permissionset 10076488 "BIFROST DIMRead ori"
{
    Assignable = true;
    Access = Public;
    Caption = 'Bifrost Dimensions Read', MaxLength = 30, Comment = 'is-IS=Bifröst - víddir (lestur)';
    IncludedPermissionSets = "BIFROST DIM ori";
}
