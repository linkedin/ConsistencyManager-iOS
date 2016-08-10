// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import UIKit

class TableViewCell: UITableViewCell {

    weak var delegate: TableViewCellDelegate?

    @IBOutlet var idLabel: UILabel!
    @IBOutlet var button: UIButton!

    @IBAction func buttonTapped() {
        delegate?.buttonWasTappedOnCell(self)
    }
}

protocol TableViewCellDelegate: class {
    func buttonWasTappedOnCell(_ cell: TableViewCell)
}
