admin = db.getSiblingDB("admin")
admin.createUser(
  {
    user: "admin",
    pwd: "admin",
    roles: [ {role: "root", db:"admin"}, { role: "userAdminAnyDatabase", db: "admin" } ]
  }
)
