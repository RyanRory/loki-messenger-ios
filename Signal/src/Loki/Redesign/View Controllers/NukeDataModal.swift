
@objc(LKNukeDataModal)
final class NukeDataModal : Modal {
    
    // MARK: Lifecycle
    override func populateContentView() {
        // Set up title label
        let titleLabel = UILabel()
        titleLabel.textColor = Colors.text
        titleLabel.font = .boldSystemFont(ofSize: Values.mediumFontSize)
        titleLabel.text = NSLocalizedString("Clear All Data", comment: "")
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.textAlignment = .center
        // Set up explanation label
        let explanationLabel = UILabel()
        explanationLabel.textColor = Colors.text.withAlphaComponent(Values.unimportantElementOpacity)
        explanationLabel.font = .systemFont(ofSize: Values.smallFontSize)
        explanationLabel.text = NSLocalizedString("This will delete your entire account, including all data, any messages currently linked to your public key, as well as your personal key pair.", comment: "")
        explanationLabel.numberOfLines = 0
        explanationLabel.textAlignment = .center
        explanationLabel.lineBreakMode = .byWordWrapping
        // Set up nuke data button
        let nukeDataButton = UIButton()
        nukeDataButton.set(.height, to: Values.mediumButtonHeight)
        nukeDataButton.layer.cornerRadius = Values.modalButtonCornerRadius
        nukeDataButton.backgroundColor = Colors.destructive
        nukeDataButton.titleLabel!.font = .systemFont(ofSize: Values.smallFontSize)
        nukeDataButton.setTitleColor(Colors.text, for: UIControl.State.normal)
        nukeDataButton.setTitle(NSLocalizedString("Delete", comment: ""), for: UIControl.State.normal)
        nukeDataButton.addTarget(self, action: #selector(nuke), for: UIControl.Event.touchUpInside)
        // Set up button stack view
        let buttonStackView = UIStackView(arrangedSubviews: [ cancelButton, nukeDataButton ])
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = Values.mediumSpacing
        buttonStackView.distribution = .fillEqually
        // Set up stack view
        let stackView = UIStackView(arrangedSubviews: [ titleLabel, explanationLabel, buttonStackView ])
        stackView.axis = .vertical
        stackView.spacing = Values.largeSpacing
        contentView.addSubview(stackView)
        stackView.pin(.leading, to: .leading, of: contentView, withInset: Values.largeSpacing)
        stackView.pin(.top, to: .top, of: contentView, withInset: Values.largeSpacing)
        contentView.pin(.trailing, to: .trailing, of: stackView, withInset: Values.largeSpacing)
        contentView.pin(.bottom, to: .bottom, of: stackView, withInset: Values.largeSpacing)
    }
    
    // MARK: Interaction
    @objc private func nuke() {
        UserDefaults.removeAll() // Not done in the nuke data implementation as unlinking requires this to happen later
        NotificationCenter.default.post(name: .dataNukeRequested, object: nil)
    }
}
