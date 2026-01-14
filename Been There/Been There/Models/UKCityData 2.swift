//
//  UKCityData.swift
//  Next-track
//
//  Static UK city data and VisitedUKCity model
//

import Foundation
import CoreLocation

// MARK: - Visited UK City Model

struct VisitedUKCity: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let region: String
    let latitude: Double
    let longitude: Double
    let radius: Double  // Highlight radius in meters

    var visitCount: Int
    var firstVisitDate: Date?
    var lastVisitDate: Date?
    var places: [String]  // Notable places visited within the city

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        name: String,
        region: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        visitCount: Int = 0,
        firstVisitDate: Date? = nil,
        lastVisitDate: Date? = nil,
        places: [String] = []
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.visitCount = visitCount
        self.firstVisitDate = firstVisitDate
        self.lastVisitDate = lastVisitDate
        self.places = places
    }

    // Format first visit date
    var formattedFirstVisit: String {
        guard let date = firstVisitDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // Format last visit date
    var formattedLastVisit: String {
        guard let date = lastVisitDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Static UK City Data

struct UKCityData {
    // Comprehensive list of UK cities and major towns with coordinates
    static let allCities: [(name: String, region: String, lat: Double, lon: Double, radius: Double)] = [
        // ========== ENGLAND ==========

        // East Midlands
        ("Nottingham", "East Midlands", 52.9548, -1.1581, 8000),
        ("Derby", "East Midlands", 52.9225, -1.4746, 7000),
        ("Leicester", "East Midlands", 52.6369, -1.1398, 8000),
        ("Lincoln", "East Midlands", 53.2307, -0.5406, 5000),
        ("Northampton", "East Midlands", 52.2405, -0.9027, 6000),

        // Lincolnshire
        ("Boston", "Lincolnshire", 52.9784, -0.0267, 5000),
        ("Grantham", "Lincolnshire", 52.9118, -0.6418, 4000),
        ("Spalding", "Lincolnshire", 52.7876, -0.1533, 3500),
        ("Skegness", "Lincolnshire", 53.1435, 0.3424, 4000),
        ("Sleaford", "Lincolnshire", 52.9966, -0.4100, 3000),

        // Nottinghamshire
        ("Sutton-in-Ashfield", "Nottinghamshire", 53.1246, -1.2614, 3000),
        ("Skegby", "Nottinghamshire", 53.1089, -1.2483, 2000),
        ("Mansfield", "Nottinghamshire", 53.1472, -1.1987, 5000),
        ("Newark-on-Trent", "Nottinghamshire", 53.0763, -0.8097, 4000),
        ("Worksop", "Nottinghamshire", 53.3043, -1.1241, 4000),

        // Greater Manchester
        ("Manchester", "Greater Manchester", 53.4808, -2.2426, 12000),
        ("Salford", "Greater Manchester", 53.4875, -2.2901, 6000),
        ("Bolton", "Greater Manchester", 53.5785, -2.4299, 6000),
        ("Stockport", "Greater Manchester", 53.4106, -2.1575, 5000),
        ("Oldham", "Greater Manchester", 53.5409, -2.1114, 5000),
        ("Rochdale", "Greater Manchester", 53.6097, -2.1561, 5000),
        ("Bury", "Greater Manchester", 53.5933, -2.2966, 4500),
        ("Wigan", "Greater Manchester", 53.5448, -2.6318, 5500),

        // Greater London
        ("London", "Greater London", 51.5074, -0.1278, 25000),
        ("Croydon", "Greater London", 51.3762, -0.0982, 5000),
        ("Bromley", "Greater London", 51.4039, 0.0198, 4500),
        ("Enfield", "Greater London", 51.6538, -0.0799, 4500),
        ("Barnet", "Greater London", 51.6444, -0.1998, 4500),
        ("Ealing", "Greater London", 51.5130, -0.3089, 4000),
        ("Hounslow", "Greater London", 51.4746, -0.3680, 4000),
        ("Kingston upon Thames", "Greater London", 51.4085, -0.3064, 3500),
        ("Richmond upon Thames", "Greater London", 51.4479, -0.3260, 3500),

        // West Midlands
        ("Birmingham", "West Midlands", 52.4862, -1.8904, 15000),
        ("Coventry", "West Midlands", 52.4068, -1.5197, 8000),
        ("Wolverhampton", "West Midlands", 52.5870, -2.1288, 6000),
        ("Dudley", "West Midlands", 52.5086, -2.0875, 5000),
        ("Walsall", "West Midlands", 52.5860, -1.9829, 5000),
        ("Solihull", "West Midlands", 52.4138, -1.7743, 5000),
        ("Hereford", "Herefordshire", 52.0565, -2.7160, 5000),
        ("Worcester", "Worcestershire", 52.1936, -2.2216, 5000),
        ("Stoke-on-Trent", "Staffordshire", 53.0027, -2.1794, 8000),
        ("Stafford", "Staffordshire", 52.8060, -2.1173, 4500),

        // Yorkshire
        ("Leeds", "West Yorkshire", 53.8008, -1.5491, 10000),
        ("Sheffield", "South Yorkshire", 53.3811, -1.4701, 10000),
        ("Bradford", "West Yorkshire", 53.7960, -1.7594, 7000),
        ("York", "North Yorkshire", 53.9600, -1.0873, 6000),
        ("Hull", "East Yorkshire", 53.7676, -0.3274, 8000),
        ("Huddersfield", "West Yorkshire", 53.6458, -1.7850, 6000),
        ("Wakefield", "West Yorkshire", 53.6833, -1.4977, 5000),
        ("Doncaster", "South Yorkshire", 53.5228, -1.1288, 6000),
        ("Rotherham", "South Yorkshire", 53.4300, -1.3568, 5000),
        ("Barnsley", "South Yorkshire", 53.5526, -1.4797, 5000),
        ("Harrogate", "North Yorkshire", 53.9921, -1.5418, 4500),
        ("Scarborough", "North Yorkshire", 54.2793, -0.4049, 5000),
        ("Middlesbrough", "North Yorkshire", 54.5742, -1.2350, 6000),

        // North East
        ("Newcastle upon Tyne", "Tyne and Wear", 54.9783, -1.6174, 10000),
        ("Sunderland", "Tyne and Wear", 54.9061, -1.3831, 7000),
        ("Durham", "County Durham", 54.7761, -1.5733, 5000),
        ("Gateshead", "Tyne and Wear", 54.9527, -1.6030, 5000),
        ("South Shields", "Tyne and Wear", 54.9988, -1.4326, 4500),

        // North West
        ("Liverpool", "Merseyside", 53.4084, -2.9916, 10000),
        ("Preston", "Lancashire", 53.7632, -2.7031, 6000),
        ("Blackpool", "Lancashire", 53.8175, -3.0357, 6000),
        ("Blackburn", "Lancashire", 53.7488, -2.4821, 5000),
        ("Burnley", "Lancashire", 53.7893, -2.2483, 4500),
        ("Lancaster", "Lancashire", 54.0465, -2.7991, 5000),
        ("Chester", "Cheshire", 53.1930, -2.8931, 5000),
        ("Warrington", "Cheshire", 53.3900, -2.5970, 5500),
        ("Crewe", "Cheshire", 53.0986, -2.4409, 4500),
        ("Carlisle", "Cumbria", 54.8951, -2.9382, 5000),
        ("Barrow-in-Furness", "Cumbria", 54.1108, -3.2261, 4500),
        ("Kendal", "Cumbria", 54.3288, -2.7458, 3500),
        ("Windermere", "Cumbria", 54.3810, -2.9080, 2500),

        // South East
        ("Oxford", "Oxfordshire", 51.7520, -1.2577, 8000),
        ("Cambridge", "Cambridgeshire", 52.2053, 0.1218, 7000),
        ("Brighton", "East Sussex", 50.8225, -0.1372, 8000),
        ("Portsmouth", "Hampshire", 50.8198, -1.0880, 8000),
        ("Southampton", "Hampshire", 50.9097, -1.4044, 9000),
        ("Reading", "Berkshire", 51.4543, -0.9781, 7000),
        ("Milton Keynes", "Buckinghamshire", 52.0406, -0.7594, 8000),
        ("Luton", "Bedfordshire", 51.8787, -0.4200, 6000),
        ("Slough", "Berkshire", 51.5105, -0.5950, 5000),
        ("Canterbury", "Kent", 51.2802, 1.0789, 5000),
        ("Maidstone", "Kent", 51.2724, 0.5290, 5000),
        ("Dover", "Kent", 51.1279, 1.3134, 4000),
        ("Guildford", "Surrey", 51.2362, -0.5704, 5000),
        ("Crawley", "West Sussex", 51.1092, -0.1872, 5000),
        ("Worthing", "West Sussex", 50.8147, -0.3714, 4500),
        ("Eastbourne", "East Sussex", 50.7684, 0.2905, 5000),
        ("Hastings", "East Sussex", 50.8543, 0.5729, 4500),
        ("Basingstoke", "Hampshire", 51.2667, -1.0870, 5000),
        ("Winchester", "Hampshire", 51.0632, -1.3080, 4500),
        ("Colchester", "Essex", 51.8959, 0.8919, 5000),
        ("Chelmsford", "Essex", 51.7356, 0.4685, 5000),
        ("Southend-on-Sea", "Essex", 51.5459, 0.7077, 6000),
        ("Ipswich", "Suffolk", 52.0567, 1.1482, 6000),
        ("Norwich", "Norfolk", 52.6309, 1.2974, 7000),
        ("Peterborough", "Cambridgeshire", 52.5695, -0.2405, 6000),

        // South West
        ("Bristol", "Avon", 51.4545, -2.5879, 10000),
        ("Bath", "Somerset", 51.3758, -2.3599, 5000),
        ("Plymouth", "Devon", 50.3755, -4.1427, 8000),
        ("Exeter", "Devon", 50.7184, -3.5339, 6000),
        ("Bournemouth", "Dorset", 50.7192, -1.8808, 7000),
        ("Poole", "Dorset", 50.7151, -1.9873, 5000),
        ("Swindon", "Wiltshire", 51.5558, -1.7797, 6000),
        ("Gloucester", "Gloucestershire", 51.8642, -2.2382, 5000),
        ("Cheltenham", "Gloucestershire", 51.8994, -2.0783, 5000),
        ("Taunton", "Somerset", 51.0215, -3.1067, 4500),
        ("Torquay", "Devon", 50.4619, -3.5253, 5000),
        ("Newquay", "Cornwall", 50.4120, -5.0757, 4000),
        ("Truro", "Cornwall", 50.2632, -5.0510, 4000),
        ("Penzance", "Cornwall", 50.1186, -5.5372, 3500),
        ("Salisbury", "Wiltshire", 51.0688, -1.7945, 4500),

        // ========== WALES ==========
        ("Cardiff", "Wales", 51.4816, -3.1791, 10000),
        ("Swansea", "Wales", 51.6214, -3.9436, 8000),
        ("Newport", "Wales", 51.5842, -2.9977, 6000),
        ("Abergavenny", "Wales", 51.8242, -3.0167, 4000),
        ("Cwmbran", "Wales", 51.6531, -3.0220, 4500),
        ("Wrexham", "Wales", 53.0469, -2.9925, 5000),
        ("Bangor", "Wales", 53.2274, -4.1293, 4000),
        ("Aberystwyth", "Wales", 52.4140, -4.0812, 4000),
        ("Cardigan", "Wales", 52.0833, -4.6667, 3500),
        ("Haverfordwest", "Wales", 51.8019, -4.9683, 4000),
        ("Llandudno", "Wales", 53.3224, -3.8275, 4000),
        ("Carmarthen", "Wales", 51.8566, -4.3117, 4000),
        ("Merthyr Tydfil", "Wales", 51.7491, -3.3787, 4500),
        ("Pontypridd", "Wales", 51.5993, -3.3422, 3500),
        ("Barry", "Wales", 51.4029, -3.2659, 4000),
        ("Caerphilly", "Wales", 51.5788, -3.2180, 3500),
        ("Bridgend", "Wales", 51.5043, -3.5768, 4000),
        ("Neath", "Wales", 51.6603, -3.8074, 3500),
        ("Port Talbot", "Wales", 51.5909, -3.7890, 4000),
        ("Milford Haven", "Wales", 51.7126, -5.0393, 3500),
        ("Pembroke", "Wales", 51.6750, -4.9150, 3000),
        ("Tenby", "Wales", 51.6728, -4.7065, 3000),
        ("Brecon", "Wales", 51.9457, -3.3980, 3000),
        ("Monmouth", "Wales", 51.8113, -2.7160, 3000),
        ("Chepstow", "Wales", 51.6413, -2.6744, 3000),

        // ========== SCOTLAND ==========
        ("Edinburgh", "Scotland", 55.9533, -3.1883, 10000),
        ("Glasgow", "Scotland", 55.8642, -4.2518, 12000),
        ("Aberdeen", "Scotland", 57.1499, -2.0938, 8000),
        ("Dundee", "Scotland", 56.4620, -2.9707, 7000),
        ("Inverness", "Scotland", 57.4778, -4.2247, 5000),
        ("Stirling", "Scotland", 56.1165, -3.9369, 4500),
        ("Perth", "Scotland", 56.3950, -3.4308, 5000),
        ("Paisley", "Scotland", 55.8456, -4.4237, 5000),
        ("Kilmarnock", "Scotland", 55.6111, -4.4950, 4500),
        ("Ayr", "Scotland", 55.4584, -4.6295, 4500),
        ("Dumfries", "Scotland", 55.0704, -3.6058, 4500),
        ("Falkirk", "Scotland", 56.0019, -3.7839, 5000),
        ("Livingston", "Scotland", 55.8864, -3.5157, 4500),
        ("Cumbernauld", "Scotland", 55.9456, -3.9940, 4000),
        ("East Kilbride", "Scotland", 55.7649, -4.1769, 5000),
        ("Hamilton", "Scotland", 55.7772, -4.0397, 4500),
        ("Motherwell", "Scotland", 55.7917, -3.9956, 4500),
        ("St Andrews", "Scotland", 56.3398, -2.7967, 3500),
        ("Fort William", "Scotland", 56.8198, -5.1052, 3000),
        ("Oban", "Scotland", 56.4126, -5.4716, 3000),

        // ========== NORTHERN IRELAND ==========
        ("Belfast", "Northern Ireland", 54.5973, -5.9301, 10000),
        ("Derry", "Northern Ireland", 54.9966, -7.3086, 6000),
        ("Lisburn", "Northern Ireland", 54.5162, -6.0580, 5000),
        ("Newry", "Northern Ireland", 54.1751, -6.3402, 4500),
        ("Bangor", "Northern Ireland", 54.6535, -5.6685, 4500),
        ("Armagh", "Northern Ireland", 54.3503, -6.6528, 4000),
        ("Craigavon", "Northern Ireland", 54.4494, -6.3875, 4500),
        ("Coleraine", "Northern Ireland", 55.1329, -6.6605, 4000),
        ("Omagh", "Northern Ireland", 54.5978, -7.3025, 3500),
        ("Enniskillen", "Northern Ireland", 54.3438, -7.6315, 3500),

        // ========== CHANNEL ISLANDS ==========
        ("St Helier", "Jersey", 49.1880, -2.1062, 3500),
        ("St Peter Port", "Guernsey", 49.4598, -2.5352, 3000),

        // ========== ISLE OF MAN ==========
        ("Douglas", "Isle of Man", 54.1509, -4.4806, 4000),
    ]

    // Get city data by name
    static func city(named name: String) -> (name: String, region: String, lat: Double, lon: Double, radius: Double)? {
        allCities.first { $0.name.lowercased() == name.lowercased() }
    }

    // Get coordinate for a city
    static func coordinate(for cityName: String) -> CLLocationCoordinate2D? {
        guard let city = city(named: cityName) else { return nil }
        return CLLocationCoordinate2D(latitude: city.lat, longitude: city.lon)
    }

    // UK center for map positioning
    static let ukCenter = CLLocationCoordinate2D(latitude: 53.5, longitude: -2.5)
    static let ukSpan = 8.0  // Degrees to show most of UK
}

// MARK: - Historical UK City Visits (Extracted from CSVs)

struct HistoricalUKCityVisits {
    // Pre-analyzed data from Visits.csv and LC_export.csv
    static let visits: [(
        cityName: String,
        visitCount: Int,
        firstVisit: (year: Int, month: Int, day: Int),
        lastVisit: (year: Int, month: Int, day: Int),
        places: [String]
    )] = [
        // Nottingham area (2025)
        ("Nottingham", 47, (2025, 5, 3), (2025, 6, 9), [
            "Queen's Medical Centre",
            "Castle Boulevard",
            "Gregory Boulevard",
            "Clifton Boulevard",
            "Beeston",
            "Attenborough Nature Reserve"
        ]),

        // Boston / Lincolnshire (2025)
        ("Boston", 52, (2025, 1, 10), (2025, 8, 5), [
            "Pilgrim Hospital",
            "Sibsey Road"
        ]),

        // Sutton-in-Ashfield (2025)
        ("Sutton-in-Ashfield", 18, (2025, 10, 13), (2025, 12, 6), [
            "King's Mill Hospital"
        ]),

        // Skegby (2025)
        ("Skegby", 5, (2025, 10, 10), (2025, 12, 24), [
            "Residential area"
        ]),

        // Manchester (2025)
        ("Manchester", 2, (2025, 5, 13), (2025, 5, 13), [
            "Manchester Piccadilly",
            "Manchester Airport"
        ]),

        // London (2019-2025) - Multiple visits
        ("London", 25, (2019, 6, 22), (2025, 12, 12), [
            "London Stansted Airport",
            "Leicester Square",
            "London Eye",
            "Waterloo Station",
            "Oxford Circus",
            "Tottenham Court Road",
            "Heathrow Airport",
            "London Designer Outlet"
        ]),

        // Abergavenny - Former home (2019-2020)
        ("Abergavenny", 312, (2019, 5, 9), (2020, 8, 6), [
            "Home",
            "Morrisons",
            "Town Centre",
            "Nevill Hall Hospital"
        ]),

        // Oxford (2019-2020)
        ("Oxford", 89, (2019, 5, 10), (2020, 11, 22), [
            "Westgate Shopping Centre",
            "John Radcliffe Hospital",
            "Thornhill Park & Ride",
            "Oxford Retail Park",
            "South Parks"
        ]),

        // Cardiff (2019)
        ("Cardiff", 3, (2019, 5, 21), (2019, 5, 21), [
            "University Hospital Wales",
            "Harlech Retail Park",
            "Cardiff West Services"
        ]),

        // Newport (2019)
        ("Newport", 15, (2019, 7, 15), (2019, 8, 8), [
            "Royal Gwent Hospital",
            "Newport Retail Park"
        ]),

        // Hereford (2019)
        ("Hereford", 1, (2019, 7, 12), (2019, 7, 12), [
            "Hereford Railway Station"
        ]),

        // Edinburgh (2020) - Scotland
        ("Edinburgh", 8, (2020, 1, 23), (2020, 1, 26), [
            "Marionville Road",
            "City Centre",
            "Royal Mile"
        ]),

        // Glasgow (2022) - Scotland
        ("Glasgow", 3, (2022, 2, 23), (2022, 2, 24), [
            "Travelodge Queen Street",
            "Glasgow Royal Infirmary",
            "Glasgow Airport"
        ]),

        // Bristol (2020)
        ("Bristol", 1, (2020, 1, 11), (2020, 1, 11), [
            "City Centre"
        ]),

        // Brighton (2021)
        ("Brighton", 2, (2021, 7, 31), (2021, 7, 31), [
            "Upside Down House",
            "Brighton Palace Pier"
        ]),

        // Guildford (2021-2022)
        ("Guildford", 15, (2021, 2, 9), (2022, 7, 27), [
            "Diagnostic Imaging Centre",
            "Big Yellow Storage",
            "Town Centre"
        ]),

        // Reading (2019-2022)
        ("Reading", 12, (2019, 11, 5), (2022, 8, 10), [
            "Reading Services (M4)",
            "Reading Tandoori"
        ]),

        // Luton (2022)
        ("Luton", 2, (2022, 2, 23), (2022, 2, 24), [
            "London Luton Airport"
        ]),

        // Southampton (2022)
        ("Southampton", 1, (2022, 7, 20), (2022, 7, 20), [
            "University Hospital Southampton"
        ]),

        // Winchester (2022)
        ("Winchester", 1, (2022, 7, 20), (2022, 7, 20), [
            "Winchester Services (M3)"
        ]),

        // Aberystwyth (2021) - Wales
        ("Aberystwyth", 1, (2021, 4, 6), (2021, 4, 6), [
            "Aberystwyth Harbour"
        ]),

        // Swansea (2021) - Wales
        ("Swansea", 1, (2021, 4, 7), (2021, 4, 7), [
            "Swansea Services"
        ]),

        // Llandudno (2021) - Wales
        ("Llandudno", 1, (2021, 6, 12), (2021, 6, 12), [
            "Llandudno Junction"
        ]),

        // Cwmbran (2022) - Wales
        ("Cwmbran", 25, (2022, 9, 8), (2022, 9, 21), [
            "Home",
            "Town Centre"
        ]),

        // Haverfordwest (2021) - Wales
        ("Haverfordwest", 1, (2021, 4, 7), (2021, 4, 7), [
            "Haverfordwest Railway Station"
        ]),

        // Birmingham (2019)
        ("Birmingham", 1, (2019, 6, 10), (2019, 6, 10), [
            "City Centre"
        ]),
    ]
}
