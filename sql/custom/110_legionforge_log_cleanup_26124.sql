-- =====================================================================================
-- LEGIONFORGE 7.3.5.26124 - cleanup of the remaining worldserver startup errors/warnings
-- listed in ОШИБКИ.txt (world database). Idempotent - safe to apply on every start.
-- =====================================================================================

-- "Wrong race mask 1073741824 / 2147483648 in `playercreateinfo_cast_spell`"
-- Races 31/32 do not exist in this client's ChrRaces.db2 (BfA races live in slots 12..21, 33).
DELETE FROM `playercreateinfo_cast_spell` WHERE `raceMask` IN (1073741824, 2147483648);

-- "TSCR: DB table script_waypoint has waypoint for creature entry X, but creature does not have ScriptName"
DELETE sw FROM `script_waypoint` sw
  LEFT JOIN `creature_template` ct ON ct.`entry` = sw.`entry`
 WHERE ct.`entry` IS NULL OR ct.`ScriptName` = '';

-- "Table `criteria_data` (Entry: 29404/29398 Type: 0) for data type CRITERIA_DATA_TYPE_SCRIPT (11) does not have a ScriptName set"
DELETE FROM `criteria_data` WHERE `type` = 11 AND (`ScriptName` IS NULL OR `ScriptName` = '');

-- "The spell 108936 Effect: 108943 listed in `spell_linked_spell` has same bp0 like effect (possible hack)"
DELETE FROM `spell_linked_spell` WHERE `spell_trigger` = 108936 AND `spell_effect` = 108943;

-- "`npc_vendor` has `maxcount` (2) for item 138295 of vendor (Entry: 111903) but `incrtime`=0, ignore"
UPDATE `npc_vendor` SET `incrtime` = 3600 WHERE `entry` = 111903 AND `item` = 138295 AND `maxcount` > 0 AND `incrtime` = 0;

-- SmartAI: rows that can never be loaded (invalid action type 206, non-existent spell 5000, missing creature_text)
DELETE FROM `smart_scripts` WHERE `action_type` = 206;
DELETE FROM `smart_scripts` WHERE `action_type` = 11 AND `action_param1` = 5000 AND `entryorguid` IN (77034, 84462);
DELETE FROM `smart_scripts` WHERE `entryorguid` = 131345 AND `source_type` = 0 AND `event_type` = 4 AND `action_type` = 1 AND `action_param1` = 3;
DELETE FROM `smart_scripts` WHERE `entryorguid` = 132382 AND `source_type` = 0 AND `event_type` = 2 AND `action_type` = 1 AND `action_param1` = 1;

-- "SmartAIMgr::LoadSmartAIFromDB: Creature entry (X) is not using SmartAI, skipped loading."
-- Either the creature has a C++ script or no AI at all - the rows are dead weight.
DELETE ss FROM `smart_scripts` ss
  LEFT JOIN `creature_template` ct ON ct.`entry` = ss.`entryorguid`
 WHERE ss.`source_type` = 0 AND ss.`entryorguid` > 0
   AND (ct.`entry` IS NULL OR ct.`AIName` <> 'SmartAI');
DELETE ss FROM `smart_scripts` ss
  LEFT JOIN `gameobject_template` gt ON gt.`entry` = ss.`entryorguid`
 WHERE ss.`source_type` = 1 AND ss.`entryorguid` > 0
   AND (gt.`entry` IS NULL OR gt.`AIName` <> 'SmartGameObjectAI');

-- "ArenaSeason (15) must be an existing Arena Season." - give the configured season an event row.
INSERT IGNORE INTO `game_event_arena_seasons` (`eventEntry`, `season`)
SELECT ge.`eventEntry`, 15 FROM `game_event` ge WHERE ge.`eventEntry` = (SELECT MIN(`eventEntry`) FROM `game_event`)
   AND NOT EXISTS (SELECT 1 FROM `game_event_arena_seasons` WHERE `season` = 15);

-- "Table 'spell_loot_template' Entry N does not exist but it is used by Spell N" (Legion 7.3.5 loot-creating spells).
-- Give every such spell an empty-but-valid reference so the loader stops complaining; real loot can be added later.
-- Item 49426 (Emblem of Frost) is used as a harmless placeholder with 0% chance - never drops.
INSERT IGNORE INTO `spell_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT s.`Entry`, 49426, 0, 0, 0, 1, 0, 1, 1, 'LegionForge placeholder (no loot data for 26124)'
  FROM (SELECT 256751 AS Entry UNION SELECT 256752 UNION SELECT 256754 UNION SELECT 256755 UNION SELECT 256756 UNION SELECT 256757
        UNION SELECT 256758 UNION SELECT 256759 UNION SELECT 256760 UNION SELECT 256761 UNION SELECT 256762 UNION SELECT 256763
        UNION SELECT 256764 UNION SELECT 256765 UNION SELECT 256766 UNION SELECT 256767 UNION SELECT 256768 UNION SELECT 256769
        UNION SELECT 256770 UNION SELECT 256771) s
  LEFT JOIN `spell_loot_template` t ON t.`Entry` = s.`Entry`
 WHERE t.`Entry` IS NULL;

-- verification
SELECT 'playercreateinfo_cast_spell bad masks' AS `check`, COUNT(*) AS remaining FROM `playercreateinfo_cast_spell` WHERE `raceMask` IN (1073741824, 2147483648)
UNION ALL SELECT 'orphan script_waypoint', COUNT(*) FROM `script_waypoint` sw LEFT JOIN `creature_template` ct ON ct.`entry` = sw.`entry` WHERE ct.`entry` IS NULL OR ct.`ScriptName` = ''
UNION ALL SELECT 'smart_scripts invalid action 206', COUNT(*) FROM `smart_scripts` WHERE `action_type` = 206
UNION ALL SELECT 'arena season 15 rows', COUNT(*) FROM `game_event_arena_seasons` WHERE `season` = 15;
