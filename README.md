
Usage:

1. Clone
2. Build **Strings** scheme using **My Mac**
3. In Terminal go to Strings folder and run the following:
```
./main.swift <sourceURL> <destinationURL>
```
`sourceURL` - URL of Localizable.Strings (english version) in your project

`destinationURL` - URL of the file with the resulting Strings struct

Example output:
```
struct Strings {
    /**
     * %1$@, %2$@ away
     */
    static func endRentalLabelDistanceToDropOff(param1: String, param2: String) -> String {
        return String(format: NSLocalizedString("end-rental.label.distance-to-drop-off", comment: "Text displayed on the alert view informing the user about the name and the distance to the nearest drop-off, e.g. 'Njalsgade, 53m away'"), param1, param2)
    }

    /**
     * I can't find the bike I rented
     */
    static func helpTitleICantFindTheBike() -> String {
        return NSLocalizedString("help.title.i-cant-find-the-bike", comment: "Help topic title")
    }
}
```
