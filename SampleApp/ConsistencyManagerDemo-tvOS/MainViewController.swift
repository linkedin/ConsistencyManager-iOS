// © 2017 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import UIKit
import ConsistencyManager


class MainViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, TableViewCellDelegate, ConsistencyManagerListener {
	
	var stream: StreamModel?
	
	@IBOutlet var tableView: UITableView!
	
	// MARK: - View Life Cycle
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		title = "Demo"
		
		ConsistencyManager.sharedInstance.addListener(self)
		
		Network.fetchUpdates() { stream in
			self.stream = stream
			ConsistencyManager.sharedInstance.addListener(self)
			self.tableView.reloadData()
		}
		
		tableView.register(UINib(nibName: "TableViewCell", bundle: nil), forCellReuseIdentifier: "cell")
	}
	
	// MARK: - Table View Delegate/DataSource
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.stream?.updates.count ?? 0
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let update = stream?.updates[(indexPath as NSIndexPath).row]
		if let update = update {
			let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
			cell.delegate = self
			cell.idLabel.text = update.id
			if update.liked {
				cell.textLabel?.text = "Unlike"
			} else {
				cell.textLabel?.text = "Like"
			}
			return cell
		} else {
			assert(false)
			return UITableViewCell()
		}
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		self.performSegue(withIdentifier: "detail", sender: self)
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 64
	}
	
	// MARK: - Cell Actions
	
	func gestureWasTappedOnCell(_ cell: TableViewCell) {
		let index = (tableView.indexPath(for: cell) as IndexPath?)?.row
		if let index = index {
			let update = stream?.updates[index]
			if let update = update {
				UpdateHelper.likeUpdate(update, like: !update.liked)
			}
		}
	}
	
	// MARK: - Consistency Manager Delegate
	
	func currentModel() -> ConsistencyManagerModel? {
		return stream
	}
	
	func modelUpdated(_ model: ConsistencyManagerModel?, updates: ModelUpdates, context: Any?) {
		if let model = model as? StreamModel {
			if model != stream {
				stream = model
				tableView.reloadData()
			}
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let vc = segue.destination as? TVDetailViewController {
			guard let row = self.tableView?.indexPathForSelectedRow?.row else { return }
			let update = stream?.updates[row]
			vc.update = update
		}
	}
}
