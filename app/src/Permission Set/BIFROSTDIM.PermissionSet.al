namespace Origo.Bifrost.Dimensions;

/// <summary>
/// Grants Bifrost Dimensions scaffold execution. Message types add their own permissions here as they are built.
/// </summary>
permissionset 10076486 "BIFROST DIM ori"
{
    Assignable = true;
    Access = Public;
    Caption = 'Bifrost Dimensions', MaxLength = 30, Comment = 'is-IS=Bifröst - víddir';
    Permissions = codeunit "Dimensions Registration ori" = X;
}
