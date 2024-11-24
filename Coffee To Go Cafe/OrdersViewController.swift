//
//  OrdersViewController.swift
//  Coffee To Go Cafe
//
//  Created by Кирилл Сысоев on 24.11.2024.
//

import UIKit
import Firebase

class OrdersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var readyOrdersTableView: UITableView!
    @IBOutlet weak var ordersInProgressTableView: UITableView!
    
    let db = Firestore.firestore()
    var readyOrders = [NewDrink]()
    var ordersInProgress = [NewDrink]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        readyOrdersTableView.dataSource = self
        readyOrdersTableView.delegate = self
        ordersInProgressTableView.dataSource = self
        ordersInProgressTableView.delegate = self
        
        loadOrdersInProgress()
        loadReadyOrders()
        
        Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(loadOrdersInProgress), userInfo: nil, repeats: true)
    }
    
    func loadReadyOrders() {
        db.collection("readyOrders").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error loading ready orders: \(error)")
                return
            }
            
            self.readyOrders = snapshot?.documents.compactMap { document in
                let data = document.data()
                let additions = data["additions"] as? [String] ?? []
                
                return NewDrink(
                    documentID: document.documentID,
                    name: data["name"] as? String ?? "",
                    description: data["description"] as? String ?? "",
                    image: data["image"] as? String ?? "",
                    price: data["price"] as? Double ?? 0,
                    category: Category(rawValue: data["category"] as? String ?? "") ?? .coffee,
                    volume: data["volume/pieces"] as? String ?? "",
                    isArabicaSelected: data["with arabica"] as? Bool ?? false,
                    isMilkSelected: data["with milk"] as? Bool ?? false,
                    isCaramelSelected: data["with caramel"] as? Bool ?? false,
                    withSyrup: data["with syrup"] as? Bool ?? false,
                    withSugar: data["with sugar"] as? Bool ?? false,
                    additions: additions
                )
            } ?? []
            
            self.readyOrdersTableView.reloadData()
        }
    }
    
    @objc func loadOrdersInProgress() {
        ordersInProgress.removeAll()
        db.collection("users").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error fetching users: \(error)")
                return
            }

            guard let userDocuments = querySnapshot?.documents else {
                print("No users found.")
                return
            }

            let userIDs = userDocuments.map { $0.documentID }
            let group = DispatchGroup()
            
            for userID in userIDs {
                let clientOrdersCollection = self.db.collection("orders").document(userID).collection("clientOrders")
                
                group.enter()
                clientOrdersCollection.getDocuments { (orderSnapshot, error) in
                    if let error = error {
                        print("Error fetching client orders for \(userID): \(error)")
                        group.leave()
                        return
                    }
                    
                    guard let orders = orderSnapshot?.documents else {
                        group.leave()
                        return
                    }

                    let newDrinks = orders.compactMap { document -> NewDrink? in
                        let data = document.data()
                        let additions = data["additions"] as? [String] ?? []
                        
                        return NewDrink(
                            documentID: document.documentID,
                            name: data["name"] as? String ?? "",
                            description: data["description"] as? String ?? "",
                            image: data["image"] as? String ?? "",
                            price: data["price"] as? Double ?? 0,
                            category: Category(rawValue: data["category"] as? String ?? "") ?? .coffee,
                            volume: data["volume/pieces"] as? String ?? "",
                            isArabicaSelected: data["with arabica"] as? Bool ?? false,
                            isMilkSelected: data["with milk"] as? Bool ?? false,
                            isCaramelSelected: data["with caramel"] as? Bool ?? false,
                            withSyrup: data["with syrup"] as? Bool ?? false,
                            withSugar: data["with sugar"] as? Bool ?? false,
                            additions: additions
                        )
                    }
                    
                    self.ordersInProgress.append(contentsOf: newDrinks)
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.ordersInProgressTableView.reloadData()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableView == readyOrdersTableView ? readyOrders.count : ordersInProgress.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "orderCell", for: indexPath) as! OrderViewCell
        let drink = tableView == readyOrdersTableView ? readyOrders[indexPath.row] : ordersInProgress[indexPath.row]
        
        cell.productImage.image = UIImage(named: drink.image)
        cell.productID.text = drink.documentID
        
        // Отладочный вывод данных
        print("Additions (Firestore): \(drink.additions)")  // Проверим массив добавок
        
        var additionsText: String
        
        if drink.additions.isEmpty {
            var additions: [String] = []
            if drink.isArabicaSelected {
                additions.append("Arabica")
            }
            if drink.isMilkSelected {
                additions.append("Milk")
            }
            if drink.isCaramelSelected {
                additions.append("Caramel")
            }
            if drink.withSyrup {
                additions.append("Syrup")
            }
            if drink.withSugar {
                additions.append("Sugar")
            }
            
            print("Additions (from flags): \(additions)")  
            
            additionsText = additions.isEmpty ? "No additions" : "+ \(additions.joined(separator: ", "))"
        } else {
            additionsText = "+ \(drink.additions.joined(separator: ", "))"
        }
        
        cell.productAdds.text = additionsText
        
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if tableView == ordersInProgressTableView {
            let readyAction = UIContextualAction(style: .normal, title: "Ready") { (action, view, completionHandler) in
                let drink = self.ordersInProgress[indexPath.row]
                
                self.db.collection("readyOrders").document(drink.documentID).setData([
                    "name": drink.name,
                    "description": drink.description,
                    "image": drink.image,
                    "price": drink.price,
                    "category": drink.category.rawValue,
                    "volume/pieces": drink.volume,
                    "additions": drink.additions
                ]) { error in
                    if let error = error {
                        print("Error moving to ready orders: \(error)")
                        completionHandler(false)
                        return
                    }
                    
                    self.db.collection("users").getDocuments { (querySnapshot, error) in
                        if let error = error {
                            print("Error fetching users: \(error)")
                            completionHandler(false)
                            return
                        }
                        
                        guard let userDocuments = querySnapshot?.documents else {
                            print("No users found.")
                            completionHandler(false)
                            return
                        }
                        
                        let group = DispatchGroup()
                        
                        for userDocument in userDocuments {
                            let userID = userDocument.documentID
                            group.enter()
                            self.db.collection("orders").document(userID).collection("clientOrders")
                                .document(drink.documentID).delete { error in
                                    if let error = error {
                                        print("Error deleting order from clientOrders for user \(userID): \(error)")
                                    } else {
                                        print("Order successfully deleted from clientOrders for user \(userID).")
                                    }
                                    group.leave()
                                }
                        }
                        
                        group.notify(queue: .main) {
                            self.ordersInProgress.remove(at: indexPath.row)
                            self.ordersInProgressTableView.deleteRows(at: [indexPath], with: .fade)
                            self.readyOrders.append(drink)
                            self.readyOrdersTableView.reloadData()
                            completionHandler(true)
                        }
                    }
                }
            }
            
            readyAction.backgroundColor = .green.withAlphaComponent(0.5)
            readyAction.image = UIImage(systemName: "checkmark.seal.fill")
            return UISwipeActionsConfiguration(actions: [readyAction])
        } else {
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { (action, view, completionHandler) in
                let drink = self.readyOrders.remove(at: indexPath.row)
                
                self.db.collection("readyOrders").document(drink.documentID).delete { error in
                    if let error = error {
                        print("Error deleting ready order: \(error)")
                    } else {
                        print("Ready order deleted.")
                    }
                }
                self.readyOrdersTableView.deleteRows(at: [indexPath], with: .fade)
                completionHandler(true)
            }
            
            deleteAction.backgroundColor = .red.withAlphaComponent(0.5)
            deleteAction.image = UIImage(systemName: "trash.fill")
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 46
    }
}
