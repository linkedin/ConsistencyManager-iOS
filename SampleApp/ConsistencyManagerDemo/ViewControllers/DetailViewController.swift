// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import UIKit
import ConsistencyManager


class DetailViewController: UIViewController, ConsistencyManagerListener {

    var update: UpdateModel

    @IBOutlet weak var likeButton: UIButton!

    init(update: UpdateModel) {
        self.update = update
        super.init(nibName: "DetailViewController", bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        edgesForExtendedLayout = UIRectEdge()
        title = update.id

        ConsistencyManager.sharedInstance.listenForUpdates(self)
        loadData()
    }

    func loadData() {
        likeButton.isHidden = false
        if update.liked {
            likeButton.setTitle("Unlike", for: UIControlState())
        } else {
            likeButton.setTitle("Like", for: UIControlState())
        }
    }

    @IBAction func deleteTapped(_ sender: UIButton) {
        ConsistencyManager.sharedInstance.deleteModel(update)
        _ = navigationController?.popViewController(animated: true)
    }

    @IBAction func likeButtonTapped(_ sender: UIButton) {
        UpdateHelper.likeUpdate(update, like: !update.liked)
    }

    // MARK - Consistency Manager Delegate

    func currentModel() -> ConsistencyManagerModel? {
        return update
    }

    func modelUpdated(_ model: ConsistencyManagerModel?, updates: ModelUpdates, context: Any?) {
        if let model = model as? UpdateModel {
            if model != update {
                update = model
                loadData()
            }
        }
    }
    
}
