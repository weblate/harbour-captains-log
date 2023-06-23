/*
 * This file is part of Captain's Log.
 * SPDX-FileCopyrightText: 2023 Mirian Margiani
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.6
import Sailfish.Silica 1.0
import SortFilterProxyModel 0.2
import Opal.InfoCombo 1.0 as I
import "../components"

Dialog {
    id: root
    allowedOrientations: Orientation.All

    property bool enableFilterSelected: false

    property var activeQueries: SearchQueriesData {}
    property SearchQueriesData queries: SearchQueriesData {
        matchAllMode: true
        text: textField.text
        textMatchSyntax: textSyntax.currentItem.mode
        textMatchMode: textMode.currentItem.mode
        dateMin: !dateMin.selectedDate || isNaN(dateMin.selectedDate.valueOf()) ?
                     queries.dateMinUnset : dateMin.selectedDate
        dateMax: !dateMax.selectedDate || isNaN(dateMax.selectedDate.valueOf()) ?
                     queries.dateMaxUnset : dateMax.selectedDate
        bookmark: bookmarks.currentItem.mode
        selected: enableFilterSelected ? onlySelected.currentItem.mode : Qt.PartiallyChecked
        tags: ([])
        tagsNormalized: ([])
        moodMin: Math.min(moodMin.moodIndex, moodMax.moodIndex)
        moodMax: Math.max(moodMin.moodIndex, moodMax.moodIndex)
    }

    onAcceptPendingChanged: {
        if (acceptPending) {
            // Copy the full query to a separate object so
            // that changing any field on the query page does
            // not automatically restart the search. Searching
            // after every key press is slow in large databases.
            activeQueries.matchAllMode = queries.matchAllMode
            activeQueries.text = queries.text
            activeQueries.textMatchSyntax = queries.textMatchSyntax
            activeQueries.textMatchMode = queries.textMatchMode
            activeQueries.dateMin = queries.dateMin
            activeQueries.dateMax = queries.dateMax
            activeQueries.bookmark = queries.bookmark
            activeQueries.selected = queries.selected
            activeQueries.tags = queries.tags
            activeQueries.tagsNormalized = queries.tagsNormalized
            activeQueries.moodMin = queries.moodMin
            activeQueries.moodMax = queries.moodMax
        }
    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.height + Theme.horizontalPageMargin

        VerticalScrollDecorator { flickable: flick }

        PullDownMenu {
            flickable: listView

            MenuItem {
                TextSwitch {
                    checked: !queries.matchAllMode
                    text: " "
                    highlighted: parent.highlighted
                    height: Theme.itemSizeSmall
                    width: height
                    anchors.verticalCenter: parent.verticalCenter
                }

                text: qsTr("Any may match")
                onClicked: queries.matchAllMode = false
            }

            MenuItem {
                TextSwitch {
                    checked: queries.matchAllMode
                    text: " "
                    highlighted: parent.highlighted
                    height: parent.height
                    width: height
                    anchors.verticalCenter: parent.verticalCenter
                }

                text: qsTr("All must match")
                onClicked: queries.matchAllMode = true
            }
        }

        Column {
            id: column
            width: parent.width

            DialogHeader {
                cancelText: qsTr("Back")
                acceptText: qsTr("Search")
            }

            SectionHeader {
                text: qsTr("Title and entry")
            }

            SearchField {
                id: textField
                width: parent.width
                placeholderText: qsTr("Search contents")
                canHide: false
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: focus = false
            }

            SelectedTagsView {
                width: parent.width
                tagsList: queries.tags

                onRemoveRequested: {
                    tagsField.text = tag
                    var index = queries.tags.indexOf(tag)

                    if (index >= 0) {
                        queries.tags.splice(index, 1)
                        queries.tagsNormalized.splice(index, 1)
                        queries.tags = queries.tags
                        queries.tagsNormalized = queries.tagsNormalized
                    }
                }
            }

            SearchField {
                id: tagsField
                width: parent.width
                placeholderText: qsTr("Search tags")
                canHide: false
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: focus = false
            }

            TagSuggestionsView {
                width: parent.width
                searchTerm: tagsField.text !== '' ?
                    tagsField.text : (tagsField.focus ? ' ' : '')

                onTagSelected: {
                    if (queries.tags.indexOf(tag.text) < 0) {
                        queries.tags = queries.tags.concat([tag.text])
                        queries.tagsNormalized = queries.tagsNormalized.concat([tag.normalized])
                    }
                }
            }

            I.InfoCombo {
                id: textSyntax
                width: parent.width
                currentIndex: 0
                label: qsTr("Search syntax")

                I.InfoComboSection {
                    title: qsTr("Note")
                    text: qsTr("Simplified matching is only possible in “plain text” " +
                               "mode.")
                    placeAtTop: true
                }

                menu: ContextMenu {
                    I.InfoMenuItem {
                        text: qsTr("plain text")
                        property int mode: RegExpFilter.FixedString
                        info: qsTr(
                            "Search for the string as you entered it. Note: some " +
                            "simplifications will be applied to the search term " +
                            "if the “Search mode” is set to “simplified”.")
                    }
                    I.InfoMenuItem {
                        text: qsTr("wildcard")
                        property int mode: RegExpFilter.WildcardUnix
                        info: qsTr(
                            "This option allows to search for extended patterns. " +
                            "Use “?” to match any single character, and “*” to " +
                            "match zero or more characters. Groups of characters " +
                            "can be defined in square brackets. Use a backslash " +
                            "to search for literal “?” or “*”, e.g. “%1”.").arg("\\?")
                    }
                    I.InfoMenuItem {
                        text: qsTr("regular expression")
                        property int mode: RegExpFilter.RegExp
                        info: qsTr(
                            "Search using complex regular expressions. Use the " +
                            "vertical bar “|” to search for multiple terms. " +
                            "Search the Internet if you want to learn more about " +
                            "regular expressions.")
                    }
                }
            }

            I.InfoCombo {
                id: textMode
                width: parent.width
                currentIndex: 0
                enabled: textSyntax.currentItem.mode === RegExpFilter.FixedString
                label: qsTr("Search mode")

                Binding on currentIndex {
                    when: !textMode.enabled
                    value: 1
                }

                menu: ContextMenu {
                    I.InfoMenuItem {
                        text: qsTr("simplified")
                        property int mode: queries.matchSimplified
                        info: qsTr(
                            "Ignore diacritics on characters, matching e.g. “ö”, “ó”, and " +
                            "“õ” when searching for “o”. Ignore any punctuation marks. " +
                            "Use this mode when you are unsure how you spelled something " +
                            "in the past.")
                    }
                    I.InfoMenuItem {
                        text: qsTr("strict")
                        property int mode: queries.matchStrict
                        info: qsTr(
                            "Match the query string exactly. Use this mode when you know exactly " +
                            "what you are searching for, or when you want to search for a string " +
                            "containing punctuation marks like “-”, “!”, or “#”."
                        )
                    }
                }
            }

            I.InfoCombo {
                id: bookmarks
                width: parent.width
                currentIndex: 0
                label: qsTr("Bookmarks")

                menu: ContextMenu {
                    I.InfoMenuItem {
                        text: qsTr("all entries", "search option, as in: " +
                                   "“find all entries, whether they are " +
                                   "bookmarked or not”")
                        property int mode: Qt.PartiallyChecked
                        info: qsTr(
                            "Find entries regardless of whether they are bookmarked " +
                            "or not.")
                    }
                    I.InfoMenuItem {
                        text: qsTr("marked", "search option, as in: " +
                                   "“find only bookmarked entries”")
                        property int mode: Qt.Checked
                        info: qsTr("Find only bookmarked entries.")
                    }
                    I.InfoMenuItem {
                        text: qsTr("unmarked", "search option, as in: " +
                                   "“find only entries that are not bookmarked”")
                        property int mode: Qt.Unchecked
                        info: qsTr("Find only entries that are not bookmarked.")
                    }
                }
            }

            I.InfoCombo {
                id: onlySelected
                width: parent.width
                currentIndex: 0
                label: qsTr("Selection")

                menu: ContextMenu {
                    I.InfoMenuItem {
                        text: qsTr("all entries", "search option, as in: " +
                                   "“find all entries, whether they are " +
                                   "currently selected or not”")
                        property int mode: Qt.PartiallyChecked
                        info: qsTr(
                            "Find entries regardless of whether they are selected " +
                            "or not.")
                    }
                    I.InfoMenuItem {
                        text: qsTr("selected", "search option, as in: " +
                                   "“find only selected entries”")
                        property int mode: Qt.Checked
                        info: qsTr("Find only currently selected entries.")
                    }
                    I.InfoMenuItem {
                        text: qsTr("unselected", "search option, as in: " +
                                   "“find only entries that are not selected")
                        property int mode: Qt.Unchecked
                        info: qsTr("Find only entries that are currently not selected.")
                    }
                }
            }

            SectionHeader {
                text: qsTr("Mood")
            }

            Row {
                width: parent.width

                ComboBox {
                    id: moodMin
                    width: parent.width / 2
                    label: qsTr("From")
                    value: appWindow.moodTexts[menu.selectedIndex]
                    property int moodIndex: menu.selectedIndex
                    menu: MoodMenu { selectedIndex: appWindow.moodTexts.length-1 }
                }

                ComboBox {
                    id: moodMax
                    width: parent.width / 2
                    label: qsTr("To")
                    value: appWindow.moodTexts[menu.selectedIndex]
                    property int moodIndex: menu.selectedIndex
                    menu: MoodMenu { selectedIndex: 0 }
                }
            }

            SectionHeader {
                text: qsTr("Entry date")
            }

            Row {
                width: parent.width

                DatePickerCombo {
                    id: dateMin
                    width: parent.width / 2
                    label: qsTr("From")
                    emptyText: qsTr("anytime", "search option, as in: " +
                                    "“match all entries regardless of their date”")
                }

                DatePickerCombo {
                    id: dateMax
                    width: parent.width / 2
                    label: qsTr("Till")
                    emptyText: qsTr("anytime", "search option, as in: " +
                                    "“match all entries regardless of their date”")
                }
            }
        }
    }
}
