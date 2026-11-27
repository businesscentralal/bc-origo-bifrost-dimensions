namespace Origo.Bifrost.Dimensions;

using Origo.Bifrost;

/// <summary>
/// Includes the matching Bifrost Dimensions permissions in the Foundation Read role.
/// </summary>
permissionsetextension 10076490 "Dimensions Read Role ori" extends "BIFROST Read ori"
{
    IncludedPermissionSets = "BIFROST DIMRead ori";
}
