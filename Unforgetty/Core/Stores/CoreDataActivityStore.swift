import CoreData
import Foundation

enum CoreDataActivityStore {
    private static let entityName = "StoredScheduledActivity"

    private static let context: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }()

    private static let coordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        try? coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeDirectory.appendingPathComponent("Activities.sqlite"),
            options: [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true
            ]
        )
        return coordinator
    }()

    private static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        entity.properties = [
            attribute("id", type: .UUIDAttributeType),
            attribute("notificationID", type: .stringAttributeType),
            attribute("surfaceRaw", type: .stringAttributeType),
            attribute("statusRaw", type: .stringAttributeType),
            attribute("liveActivityID", type: .stringAttributeType, isOptional: true),
            attribute("startDate", type: .dateAttributeType),
            attribute("endDate", type: .dateAttributeType, isOptional: true),
            attribute("createdAt", type: .dateAttributeType),
            attribute("payload", type: .binaryDataAttributeType)
        ]

        model.entities = [entity]
        return model
    }()

    private static var storeDirectory: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent("Unforgetty", isDirectory: true)
    }

    static func load() -> [ScheduledActivity] {
        let mirroredActivities = SharedActivityStore.load()
        if !mirroredActivities.isEmpty {
            save(mirroredActivities)
            return mirroredActivities
        }

        return fetchStoredActivities()
    }

    static func save(_ activities: [ScheduledActivity]) {
        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            if let storedObjects = try? context.fetch(fetchRequest) as? [NSManagedObject] {
                storedObjects.forEach(context.delete)
            }

            for activity in activities {
                let object = NSManagedObject(entity: entityDescription, insertInto: context)
                object.setValue(activity.id, forKey: "id")
                object.setValue(activity.notificationID, forKey: "notificationID")
                object.setValue(activity.surface.rawValue, forKey: "surfaceRaw")
                object.setValue(activity.status.rawValue, forKey: "statusRaw")
                object.setValue(activity.liveActivityID, forKey: "liveActivityID")
                object.setValue(activity.startDate, forKey: "startDate")
                object.setValue(activity.endDate, forKey: "endDate")
                object.setValue(activity.createdAt, forKey: "createdAt")
                object.setValue(try? JSONEncoder().encode(activity), forKey: "payload")
            }

            try? context.save()
        }
    }

    private static var entityDescription: NSEntityDescription {
        NSEntityDescription.entity(forEntityName: entityName, in: context) ?? model.entitiesByName[entityName]!
    }

    private static func fetchStoredActivities() -> [ScheduledActivity] {
        var activities: [ScheduledActivity] = []
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
            guard let objects = try? context.fetch(request) else { return }
            activities = objects.compactMap { object in
                guard let data = object.value(forKey: "payload") as? Data else { return nil }
                return try? JSONDecoder().decode(ScheduledActivity.self, from: data)
            }
        }
        return activities
    }

    private static func attribute(_ name: String, type: NSAttributeType, isOptional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }
}
