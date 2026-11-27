namespace Origo.Bifrost.Dimensions;

/// <summary>
/// Full Bifrost Dimensions role. Includes the read role; message types add their write permissions here as they are built.
/// </summary>
permissionset 10076487 "BIFROST DIMFull ori"
{
    Assignable = true;
    Access = Public;
    Caption = 'Bifrost Dimensions Full', MaxLength = 30, Comment = 'is-IS=Bifröst - víddir (fullt)';
    IncludedPermissionSets = "BIFROST DIMRead ori";
}
