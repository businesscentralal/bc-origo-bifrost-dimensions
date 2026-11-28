namespace Origo.Bifrost.Dimensions;

/// <summary>
/// A supported posted ledger or posted document table. The implementation names the table, its key, Dimension Set ID,
/// global and shortcut dimension fields, posting date, document no., source no. and, for a document header, the line
/// table and the header-to-line link.
/// </summary>
interface "Dim. Correction Target ori"
{
    /// <summary>Describes the target as a JSON object.</summary>
    /// <param name="Target">The registry value being described; one implementation may serve several values.</param>
    /// <returns>The descriptor with name, tableNo, kind, keyField, documentNoField, postingDateField, sourceNoField, descriptionField, dimensionSetIdField and, for documents, lineTableNo and lineLinkField.</returns>
    procedure Describe(Target: Enum "Dim. Correction Target ori"): JsonObject;
}
