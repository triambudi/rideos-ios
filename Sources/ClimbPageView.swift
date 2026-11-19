import UIKit

/// Halaman tanjakan (versi awal): ketinggian, kemiringan saat ini, total naik/turun, profil jalur terakhir.
final class ClimbPageView: PageView {
    private let altCell = CellView(title: "Ketinggian m", valueSize: 30)
    private let gradeCell = CellView(title: "Kemiringan %", valueSize: 30)
    private let gainCell = CellView(title: "Naik m", valueSize: 30)
    private let lossCell = CellView(title: "Turun m", valueSize: 30)
    private let profileCell = UIView()
    private let profileTitle = UILabel()
    private let profile = ProfileView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        applyTheme()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        let row1 = UIStackView(arrangedSubviews: [altCell, gradeCell])
        let row2 = UIStackView(arrangedSubviews: [gainCell, lossCell])
        for r in [row1, row2] {
            r.axis = .horizontal
            r.spacing = 6
            r.distribution = .fillEqually
        }

        profileCell.layer.cornerRadius = 10
        profileTitle.text = "Profil ketinggian jalur terakhir"
        profileTitle.font = .systemFont(ofSize: 11, weight: .medium)
        let subs: [UIView] = [profileTitle, profile]
        for v in subs {
            v.translatesAutoresizingMaskIntoConstraints = false
            profileCell.addSubview(v)
        }
        NSLayoutConstraint.activate([
            profileTitle.topAnchor.constraint(equalTo: profileCell.topAnchor, constant: 8),
            profileTitle.leadingAnchor.constraint(equalTo: profileCell.leadingAnchor, constant: 8),
            profile.topAnchor.constraint(equalTo: profileTitle.bottomAnchor, constant: 8),
            profile.leadingAnchor.constraint(equalTo: profileCell.leadingAnchor, constant: 8),
            profile.trailingAnchor.constraint(equalTo: profileCell.trailingAnchor, constant: -8),
            profile.bottomAnchor.constraint(equalTo: profileCell.bottomAnchor, constant: -8)
        ])

        let main = UIStackView(arrangedSubviews: [row1, row2, profileCell])
        main.axis = .vertical
        main.spacing = 6
        main.alignment = .fill
        main.translatesAutoresizingMaskIntoConstraints = false
        addSubview(main)
        NSLayoutConstraint.activate([
            main.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            main.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            main.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            main.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            row1.heightAnchor.constraint(equalToConstant: 96),
            row2.heightAnchor.constraint(equalToConstant: 96)
        ])
    }

    override func applyTheme() {
        [altCell, gradeCell, gainCell, lossCell].forEach { $0.applyTheme() }
        profileCell.backgroundColor = Theme.cell
        profileTitle.textColor = Theme.muted
        profile.setNeedsDisplay()
    }

    override func update(_ e: RideEngine) {
        altCell.valueLabel.text = e.hasAltitude ? "\(Int(e.altitude.rounded()))" : "--"
        gradeCell.valueLabel.text = String(format: "%.1f", e.grade)
        gradeCell.valueLabel.textColor = e.state == .idle ? Theme.fg : gradeColor(e.grade)
        gainCell.valueLabel.text = "\(Int(e.gainM.rounded()))"
        lossCell.valueLabel.text = "\(Int(e.lossM.rounded()))"
        profile.samples = e.profile
    }
}
