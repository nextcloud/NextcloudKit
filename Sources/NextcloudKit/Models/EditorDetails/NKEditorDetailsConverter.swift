import Foundation

public enum NKEditorDetailsConverter {

    /// Parses and converts raw JSON `Data` into `[NKEditorDetailsEditors]` and `[NKEditorDetailsCreators]`.
    /// - Parameter data: Raw JSON `Data` from the editors/creators endpoint.
    /// - Returns: A tuple with editors and creators.
    /// - Throws: Decoding error if parsing fails.
    public static func from(data: Data) throws -> (editors: [NKEditorDetailsEditor], creators: [NKEditorDetailsCreator]) {
        data.printJson()

        let decoded = try JSONDecoder().decode(NKEditorDetailsResponse.self, from: data)
        let editors = decoded.ocs.data.editorsArray()
        let creators = decoded.ocs.data.creatorsArray()
    
        return (editors, creators)
    }
}
