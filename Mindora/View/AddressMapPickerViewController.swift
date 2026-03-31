import UIKit
import MapKit
import CoreLocation

// Model for search results
struct LocationItem {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let region: String // State + City + District
    let detail: String // Street + Name
}

class AddressMapPickerViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Properties
    var onSelectLocation: ((LocationItem) -> Void)?
    
    private let locationManager = CLLocationManager()
    private var searchCompleter = MKLocalSearchCompleter()
    private var mapItems: [MKMapItem] = []
    private var centerLocationItem: LocationItem?
    private let geocoder = CLGeocoder() // Reuse geocoder
    
    // MARK: - UI Elements
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 24/255.0, green: 24/255.0, blue: 24/255.0, alpha: 1.0)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let backButton: EnlargedHitAreaButton = {
        let button = EnlargedHitAreaButton()
        button.setImage(UIImage(named: "sub_back"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = L("address.select_title")
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let mapView: MKMapView = {
        let map = MKMapView()
        map.translatesAutoresizingMaskIntoConstraints = false
        map.showsUserLocation = true
        return map
    }()
    
    private let centerPin: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "mappin.circle.fill")) // Fallback if no asset
        // Ideally use brand asset or a generic pin
        iv.tintColor = .red
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let bottomSheet: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 30/255.0, green: 30/255.0, blue: 30/255.0, alpha: 1.0)
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private var isFirstLocationUpdate = true
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        mapView.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AddressMapCell.self, forCellReuseIdentifier: "AddressMapCell")
    }
    
    private func setupUI() {
        view.addSubview(mapView)
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(titleLabel)
        
        view.addSubview(centerPin)
        view.addSubview(bottomSheet)
        bottomSheet.addSubview(tableView)
        
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),
            
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            mapView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.heightAnchor.constraint(equalToConstant: 300), // Map takes top portion
            
            centerPin.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
            centerPin.centerYAnchor.constraint(equalTo: mapView.centerYAnchor, constant: -16), // Offset for pin point
            centerPin.widthAnchor.constraint(equalToConstant: 32),
            centerPin.heightAnchor.constraint(equalToConstant: 32),
            
            bottomSheet.topAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -16), // Overlap visually
            bottomSheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomSheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomSheet.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            tableView.topAnchor.constraint(equalTo: bottomSheet.topAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: bottomSheet.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: bottomSheet.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomSheet.bottomAnchor)
        ])
    }
    
    @objc private func handleBack() {
        dismiss(animated: true)
    }
    
    // MARK: - Location & Map
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, isFirstLocationUpdate else { return }
        isFirstLocationUpdate = false
        
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: true)
        
        // Initial search around current location
        searchNearby(location.coordinate)
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // When user drags map, search around new center
        searchNearby(mapView.centerCoordinate)
    }
    
    private func searchNearby(_ coordinate: CLLocationCoordinate2D) {
        // 1. Reverse Geocode the center point
        let centerLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // Cancel previous geocode if possible? (Simpler to just run new one)
        
        geocoder.reverseGeocodeLocation(centerLoc) { [weak self] (placemarks, error) in
            guard let self = self, let placemark = placemarks?.first else { return }
            
            var regionParts: [String] = []
            if let admin = placemark.administrativeArea { regionParts.append(admin) }
            if let locality = placemark.locality, locality != placemark.administrativeArea { regionParts.append(locality) }
            if let sub = placemark.subLocality { regionParts.append(sub) }
            
            let region = regionParts.joined(separator: " ")
            
            // Construct detail
            var detail = ""
            if let name = placemark.name { detail = name }
            if let th = placemark.thoroughfare { 
                if detail.contains(th) == false { // Avoid dup
                    detail = th + (placemark.subThoroughfare ?? "")
                }
            }
            if detail.isEmpty { detail = region } // Fallback
            
            // Create item for "Current Map Center"
            self.centerLocationItem = LocationItem(
                name: L("address.current_location"), 
                address: region,
                coordinate: coordinate,
                region: region,
                detail: detail
            )
            self.tableView.reloadData()
        }
    
        // 2. Search POIs
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "Place" // Generic query
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] (response, error) in
            guard let self = self, let items = response?.mapItems else { return }
            self.mapItems = items
            self.tableView.reloadData()
        }
    }
    
    // MARK: - TableView
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return centerLocationItem != nil ? 1 : 0
        }
        return mapItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AddressMapCell") as? AddressMapCell else {
             return UITableViewCell()
        }
        
        if indexPath.section == 0 {
            if let item = centerLocationItem {
                cell.configure(title: item.name, subtitle: item.detail) 
                cell.titleLabel.textColor = .systemBlue 
                cell.titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
            }
        } else {
            let item = mapItems[indexPath.row]
            let name = item.name ?? ""
            let addr = item.placemark.title ?? "" 
            cell.configure(title: name, subtitle: addr)
            cell.titleLabel.textColor = .white
            cell.titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedItem: LocationItem
        
        if indexPath.section == 0 {
            guard let item = centerLocationItem else { return }
            selectedItem = item
        } else {
            let item = mapItems[indexPath.row]
            let placemark = item.placemark
            
            var regionParts: [String] = []
            if let admin = placemark.administrativeArea { regionParts.append(admin) }
            if let locality = placemark.locality, locality != placemark.administrativeArea { regionParts.append(locality) }
            if let sub = placemark.subLocality { regionParts.append(sub) }
            
            let region = regionParts.joined(separator: " ")
            let detail = item.name ?? placemark.thoroughfare ?? ""
            
            selectedItem = LocationItem(
                name: item.name ?? "",
                address: placemark.title ?? "",
                coordinate: placemark.coordinate,
                region: region,
                detail: detail
            )
        }
        
        onSelectLocation?(selectedItem)
        dismiss(animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
}

class AddressMapCell: UITableViewCell {
    
    let titleLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    let subtitleLabel: UILabel = {
        let l = UILabel()
        l.textColor = .lightGray
        l.font = .systemFont(ofSize: 22)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}
