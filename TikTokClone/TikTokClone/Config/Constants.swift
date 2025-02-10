import Foundation

enum Constants {
    enum Appwrite {
        static let endpoint = "https://cloud.appwrite.io/v1"
        static let databaseId = "67a580230029e01e56af"
        
        enum Collections {
            static let reactions = "67a5806500128aef9d88"
        }
        
        enum Buckets {
            static let main = "67a5108e001f86591b24"
        }
    }
    
    enum Media {
        static let audio = [
            "sound1": "67a5112d0010c1dac2f0",
            "sound2": "67a5113b0018308eabee",
            "sound3": "67a511450021836345be"
        ]
        
        static let muxVideos = [
            "cooking": [
                "feFaCHnNI3vl3rN01G01ExZrXsSxHhKxuYT1p01Yw21FKc",
                "dmbxsATxsA0100168N99vkIaP3KEq2NIv1TPcoSrSV4xI",
                "Ok1lWjHbf00tr2HKZlI2wkiJ822MaYG9x91AjWPS6y400"
            ],
            "walking": [
                "eVr202tnkQGDB1ygarME100JgaucpqJDZMFCyukB00q3L8",
                "CHV01yItQU4sjxavbg4G4Ql5spm302tgoQvM8wAy01e5D00",
                "4lMr2Mzg68eS3GLd8aC5iJ5nlMr01jkn1dPsq4CDmrTg"
            ],
            "meditation": ["QHVtYewW3ozRJvKhCcDfZvdiMd6GG7meZm001lkakOSg"]
        ]
    }
} 