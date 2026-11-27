namespace Origo.Bifrost.Dimensions.Test;

using Origo.Bifrost;
using System.Environment.Configuration;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Supplies platform reads and execute on the test codeunits and libraries for the restricted tests.
/// Product execute and administrator permissions must come from the real product roles.
/// </summary>
permissionset 98301 "Dim Setup Test ori"
{
    Assignable = true;
    Caption = 'Setup test platform', Locked = true;
    IncludedPermissionSets = "Guided Experience - View";
    Permissions =
        tabledata "NAV App Setting" = r,
        tabledata "Setup ori" = R,
        codeunit "Dimensions Scaffold Tst ori" = X,
        codeunit "Dim Setup Msg Tst ori" = X,
        codeunit "Library Assert" = X,
        codeunit "Library - Lower Permissions" = X,
        codeunit "Permissions Mock" = X;
}
