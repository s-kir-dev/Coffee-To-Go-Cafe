//
//  OrderTableViewCell.swift
//  Coffee To Go Cafe
//
//  Created by Кирилл Сысоев on 24.11.2024.
//

import UIKit

class OrderViewCell: UITableViewCell {

    @IBOutlet weak var productImage: UIImageView!
    @IBOutlet weak var productAdds: UILabel!
    @IBOutlet weak var productID: UILabel!


    override func awakeFromNib() {
        super.awakeFromNib()
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
    }
}
