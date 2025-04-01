#!/bin/bash

KEYFILE="/etc/mongo-keyfile"
MARKER="/data/db/.auth_ready"

chmod 600 $KEYFILE

if [ ! -f "$MARKER" ]; then
  echo "🟡 First boot – setting up replica set WITHOUT auth..."

  # Bắt đầu mongod tạm thời KHÔNG có --auth
  mongod --replSet rs0 --bind_ip_all --keyFile $KEYFILE --fork --logpath /var/log/mongodb.log

  echo "⏳ Waiting for mongod to be ready..."
  sleep 8

  mongosh --eval '
    rs.initiate({
      _id: "rs0",
      members: [
        { _id: 0, host: "127.0.0.1:27017", priority: 2 },
        { _id: 1, host: "127.0.0.1:27018", priority: 1 },
        { _id: 2, host: "127.0.0.1:27019", priority: 1 }
      ]
    });

    function waitForPrimary() {
      while (true) {
        try {
          const status = rs.status();
          if (status.myState === 1) {
            print("✅ Primary ready 🚀");
            break;
          }
        } catch (e) {}
        print("... waiting for primary ...");
        sleep(1000);
      }
    }

    waitForPrimary();

    db = db.getSiblingDB("admin");
    db.createUser({
      user: "root",
      pwd: "example",
      roles: [{ role: "root", db: "admin" }]
    });

    print("✅ Root user created.");
  '

  # Shutdown mongod KHÔNG auth
  mongod --shutdown --dbpath /data/db

  # Đánh dấu đã init
  touch $MARKER
  echo "✅ Replica set + root user created. Will now restart with auth."
fi

# Giai đoạn 2: Khởi động mongod chính thức CÓ auth
exec mongod --replSet rs0 --bind_ip_all --auth --keyFile $KEYFILE
