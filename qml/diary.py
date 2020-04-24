# coding: utf-8

import os
import csv
import sqlite3

# - - - basic settings - - - #

home = os.getenv("HOME")
db_path = home+"/.local/share/harbour-captains-log"

if os.path.isdir(db_path) == False:
    print("Create app path in .local/share")
    os.mkdir(db_path)

database = db_path + "/logbuch.db"
schema = db_path + "/schema_version"
filtered_entry_list = []
schema_version = "none"

conn = sqlite3.connect(database)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

def upgrade_schema(from_version):
    to_version = ""

    if from_version == "none":
        to_version = "0"
        cursor.execute("""CREATE TABLE IF NOT EXISTS diary
                          (creation_date TEXT NOT NULL,
                           modify_date TEXT NOT NULL,
                           mood INT,
                           title TEXT,
                           preview TEXT,
                           entry TEXT,
                           favorite BOOL,
                           hashtags TEXT
                           );""")
    elif from_version == "0":
        to_version = "1"

        # add new mood 'not okay' with index 3, moving 3 to 4, and 4 to 5
        cursor.execute("""UPDATE diary SET mood=5 WHERE mood=4""")
        cursor.execute("""UPDATE diary SET mood=4 WHERE mood=3""")
    elif from_version == "1":
        to_version = "2"

        # add columns to store time zone info
        cursor.execute("""ALTER TABLE diary ADD COLUMN creation_tz TEXT DEFAULT '';""")
        cursor.execute("""ALTER TABLE diary ADD COLUMN modify_tz TEXT DEFAULT '';""")

        # add column to store an audio file path (not yet used)
        cursor.execute("""ALTER TABLE diary ADD COLUMN audio_path TEXT DEFAULT '';""")
    elif from_version == "2":
        # we arrived at the latest version; save it and return
        if schema_version != from_version:
            conn.commit()
            with open(schema, "w") as f:
                f.write(from_version)
        print("database schema is up-to-date (version: {})".format(from_version))
        return
    else:
        print("Invalid schema version!", from_version)
        return

    print("upgrading schema from {} to {}...".format(from_version, to_version))
    upgrade_schema(to_version)


if os.path.isfile(schema) == False:
    schema_version = "none"
else:
    with open(schema) as f:
        schema_version = f.readline().strip()

# make sure database is up-to-date
upgrade_schema(schema_version)


# - - - database functions - - - #

def read_all_entries():
    """ Read all entries to show them on the main page """
    cursor.execute(""" SELECT *, rowid FROM diary ORDER BY rowid DESC; """)
    rows = cursor.fetchall()
    return create_entries_model(rows)


def add_entry(creation_date, mood, title, preview, entry, hashs):
    """ Add new entry to the database. By default last modification is set to NULL and favorite option to FALSE. """
    cursor.execute("""INSERT INTO diary
                      (creation_date, modify_date, mood, title, preview, entry, favorite, hashtags)
                      VALUES (?, "", ?, ?, ?, ?, 0, ?);""",
                      (creation_date, mood, title.strip(), preview.strip(), entry.strip(), hashs.strip()))
    conn.commit()

    entry = {"create_date": creation_date,
             "day": creation_date.split(' | ')[0],
             "modify_date": "",
             "mood": mood,
             "title": title.strip(),
             "preview": preview.strip(),
             "entry": entry.strip(),
             "favorite": False,
             "hashtags": hashs.strip(),
             "rowid": cursor.lastrowid}
    return entry


def update_entry(modify_date, mood, title, preview, entry, hashs, id):
    """ Updates an entry in the database. """
    cursor.execute("""UPDATE diary
                          SET modify_date = ?,
                              mood = ?,
                              title = ?,
                              preview = ?,
                              entry = ?,
                              hashtags = ?
                          WHERE
                              rowid = ?;""",
                              (modify_date, mood, title.strip(), preview.strip(), entry.strip(), hashs.strip(), id))
    conn.commit()


def update_favorite(id, fav):
    """ Just updates the status of the favorite option """
    cursor.execute(""" UPDATE diary
                       SET favorite = ?
                       WHERE rowid = ?; """, (1 if fav else 0, id))
    conn.commit()


def delete_entry(id):
    """ Deletes an entry from the diary table """
    cursor.execute(""" DELETE FROM diary
                       WHERE rowid = ?; """, (id, ))
    conn.commit()


# - - - search functions - - - #


def search_entries(keyword):
    """ Searches for the keyword in the database """
    cursor.execute(""" SELECT *, rowid FROM diary WHERE title LIKE ? OR entry LIKE ? OR hashtags LIKE ? ORDER BY rowid DESC; """, ("%"+keyword+"%", "%"+keyword+"%", "%"+keyword+"%"))
    rows = cursor.fetchall()
    create_entries_model(rows)


def search_date(dateStr):
    """ Search for a date string """
    cursor.execute(""" SELECT *, rowid FROM diary WHERE creation_date LIKE ? ORDER BY rowid DESC; """, (dateStr.split(' | ')[0]+"%", ))
    rows = cursor.fetchall()
    create_entries_model(rows)

def search_hashtags(hash):
    """ Search for a specific hashtag """
    cursor.execute(""" SELECT *, rowid FROM diary WHERE hashtags LIKE ? ORDER BY rowid DESC; """, ("%"+hash+"%", ))
    rows = cursor.fetchall()
    create_entries_model(rows)


def search_favorites():
    """ Returns list of all favorites """
    cursor.execute(""" SELECT *, rowid FROM diary WHERE favorite = 1 ORDER BY rowid DESC; """)
    rows = cursor.fetchall()
    create_entries_model(rows)


def search_mood(mood):
    """ Return list of all entries with specific mood """
    cursor.execute(""" SELECT *, rowid FROM diary WHERE mood = ? ORDER BY rowid DESC; """, (mood, ))
    rows = cursor.fetchall()
    create_entries_model(rows)


# - - - QML model creation functions - - - #

def create_entries_model(rows):
    """ Create the QML ListModel to be shown on main page """

    filtered_entry_list.clear()

    for row in rows:
        entry = {"create_date": row["creation_date"],
                 "day": row["creation_date"].split(' | ')[0],
                 "modify_date": row["modify_date"],
                 "mood": row["mood"],
                 "title": row["title"].strip(),
                 "preview": row["preview"].strip(),
                 "entry": row["entry"].strip(),
                 "favorite": True if row["favorite"] == 1 else False,
                 "hashtags": row["hashtags"].strip(),
                 "rowid": row["rowid"]}
        filtered_entry_list.append(entry)
    return filtered_entry_list


def get_filtered_entry_list():
    """ return the latest status of the entries list """
    return filtered_entry_list


# - - - export features - - - #


def export(filename, type):
    """ Export to ~/filename as txt or csv """

    # get latest state of the database
    rows = read_all_entries()

    moods = ["Fantastic", "Good", "Okay", "Not okay", "Bad", "Horrible"]

    # Export as *.txt text file to filename
    if type == ".txt":
        with open(filename, "w") as f:
            for r in rows:
                # TODO include time zones
                # TODO use format strings
                date_str = r["create_date"]+" (changed: "+r["modify_date"]+")\n\n"
                title_str = "Title: "+r["title"]+"\n\n"
                entry_str = "Entry:\n"+r["entry"]+"\n\n"
                hash_str = "Hashtags: "+r["hashtags"]+"\n"
                if r["favorite"]:
                    fav_str = "Favorite: Yes!\n"
                else:
                    fav_str = "Favorite: - \n"
                mood_str = "Mood: "+moods[r["mood"]]+"\n\n"
                split_str = "-------------------------------------------------------------------------------\n\n"

                final_str = date_str + title_str + entry_str + hash_str + fav_str + mood_str + split_str
                f.write(final_str)
            f.close()

    # Export as *.csv file to filename
    if type == ".csv":
        with open(filename, "w", newline='') as f:
            # TODO load field names from db
            fieldnames = ["rowid", "create_date", "creation_tz", "modify_date", "modify_tz", "mood", "preview", "title", "entry", "hashtags", "favorite"]
            csv_writer = csv.DictWriter(f, fieldnames=fieldnames)

            csv_writer.writeheader()

            for r in rows:
                csv_writer.writerow(r)

            f.close()
