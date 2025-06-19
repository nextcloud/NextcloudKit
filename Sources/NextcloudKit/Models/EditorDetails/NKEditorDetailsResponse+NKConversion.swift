import Foundation


public extension NKEditorDetailsResponse.OCS.DataClass {

    func editorsArray() -> [NKEditorDetailsEditor] {
        Array(editors.values)
    }

    func creatorsArray() -> [NKEditorDetailsCreator] {
        Array(creators.values)
    }
}
