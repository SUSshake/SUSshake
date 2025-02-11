dofile( "$CONTENT_DATA/Scripts/game/managers/LanguageManager.lua" ) --RAFT

QuestManager = class( nil )
QuestManager.isSaveObject = true

QuestEvent = {
	QuestActivated = "event.generic.quest_activated", -- data.params: { questName = ? }
	QuestCompleted = "event.generic.quest_completed", -- data.params: { questName = ? }
	QuestAbandoned = "event.generic.quest_abandoned", -- data.params: { questName = ? }
	InventoryChanges = "event.generic.inventory_changes", -- data.params: { container = ?, changes = { { uuid = ?, difference = ? [, instance = ?] } }, ... }
	InteractableCreated = "event.generic.interactable_created", -- data.params: { interactable = ? }
	InteractableDestroyed = "event.generic.interactable_destroyed", -- data.params: { interactable = ? }
	WaypointLoaded = "event.generic.waypoint_loaded", -- { data.params: waypoint = ?, world = ? }
	AreaTriggerEnter = "event.generic.areaTrigger_enter", -- { data.params: name = ?, results = { ? } }
	AreaTriggerExit = "event.generic.areaTrigger_exit", -- { data.params: name = ?, results = { ? } }
	PlayerJoined = "event.generic.player_joined", -- data.params: { questName = ? }
	PlayerLeft = "event.generic.player_left", -- data.params: { questName = ? }

	--RAFT
	Sleep = "event.raft.sleep",
	Workbench = "event.raft.workbench",
	ReadLog = "event.raft.log_read",
	Craftbot = "event.raft.craftbot",
	Antenna = "event.raft.antenna",
	TraderNotes = "event.raft.trader_notes",
	TraderTalk = "event.raft.trader_talk",
	Vegetables = "event.raft.vegetables",
	SunshakeRecipe = "event.raft.sunshake_recipes",
	Fruits = "event.raft.fruits",
	Warehouse = "event.raft.warehouse",
	FarmerTalk = "event.raft.farmer_talk",
	FarmerSuck = "event.raft.farmer_suck",
}

local function LoadQuestSet( path, questTable )
	if sm.json.fileExists( path ) then
		local questSet = sm.json.open( path )
		if questSet and questSet.scriptableObjectList then
			for _, questEntries in pairs( questSet.scriptableObjectList ) do
				if questEntries.name and questEntries.uuid then
					questTable[questEntries.name] = sm.uuid.new( questEntries.uuid )
				end
			end
		end
	else
		sm.log.error("Failed to load quest set " .. path .. " file did not exist.")
	end
end

function QuestManager.server_onCreate( self )
	assert( g_questManager == nil )

	g_questManager = self
	self.sv = {}
	self.sv.saved = self.storage:load()
	if not self.sv.saved then
		self.sv.saved = {}
		self.sv.saved.activeQuests = {}
		self.sv.saved.completedQuests = {}
		self.storage:save( self.sv.saved )
	else
		self.network:setClientData( self.sv.saved )
	end
	self.sv.eventSubs = {}
	self.sv.quests = {}

	LoadQuestSet( "$CONTENT_DATA/ScriptableObjects/scriptableObjectSets/sob_quests.sobset", self.sv.quests )--RAFT

	QuestManager.Sv_SubscribeEvent( QuestEvent.QuestCompleted, self.scriptableObject, "sv_e_onQuestEvent" )--RAFT


end

function QuestManager.server_onDestroy( self )
	g_questManager = nil
	if self.sv.activeQuests then
		for _, quest in pairs( self.sv.activeQuests ) do
			quest:destroy()
			quest = nil
		end
	end
end

function QuestManager.client_onCreate( self )
	if not sm.isHost then
		g_questManager = self
	end
	self.cl = {}
	self.cl.completedQuests = {}
	self.cl.activeQuests = {}
	self.cl.trackerHud = sm.gui.createQuestTrackerGui()
	self.cl.trackerHud:open()
	self.cl.questTrackerDirty = true
end

function QuestManager.client_onDestroy( self )
	g_questManager = nil
	self.cl.trackerHud = nil
end

function QuestManager.Sv_ActivateQuest( questName )
	if g_questManager then
		print( "QuestManager - ActivateQuest:", questName )
		sm.event.sendToScriptableObject( g_questManager.scriptableObject, "sv_e_activateQuest", questName )
	end
end

function QuestManager.Sv_TryActivateQuest( questName )
	if not QuestManager.Sv_IsQuestActive( questName ) and not QuestManager.Sv_IsQuestComplete( questName ) then
		QuestManager.Sv_ActivateQuest( questName )
	end
end

function QuestManager.Sv_AbandonQuest( questName )
	if g_questManager then
		print( "QuestManager - AbandonQuest:", questName )
		sm.event.sendToScriptableObject( g_questManager.scriptableObject, "sv_e_abandonQuest", questName )
	end
end

function QuestManager.Sv_TryAbandonQuest( questName )
	if QuestManager.Sv_IsQuestActive( questName ) then
		QuestManager.Sv_AbandonQuest( questName )
	end
end

function QuestManager.Sv_CompleteQuest( questName )
	if g_questManager then
		print( "QuestManager - CompleteQuest:", questName )
		sm.event.sendToScriptableObject( g_questManager.scriptableObject, "sv_e_completeQuest", questName )
	end
end

function QuestManager.Sv_IsQuestActive( questName )
	if g_questManager then
		return g_questManager:sv_isQuestActive( questName )
	end
end

function QuestManager.Sv_IsQuestComplete( questName )
	if g_questManager then
		return g_questManager:sv_isQuestComplete( questName )
	end
end

function QuestManager.Sv_GetQuest( questName )
	if g_questManager then
		return g_questManager:sv_getQuest( questName )
	end
end

function QuestManager.Sv_SubscribeEvent( event, subscriber, methodName )
	if g_questManager then
		g_questManager:sv_subscribeEvent( event, subscriber, methodName )
	end
end

function QuestManager.Sv_UnsubscribeEvent( event, subscriber )
	if g_questManager then
		g_questManager:sv_unsubscribeEvent( event, subscriber )
	end
end

function QuestManager.Sv_UnsubscribeAllEvents( subscriber )
	if g_questManager then
		g_questManager:sv_unsubscribeAllEvents( subscriber )
	end
end

function QuestManager.Sv_OnEvent( event, params )
	if g_questManager then
		g_questManager:sv_onEvent( event, params )
	end
end

function QuestManager.Cl_IsQuestActive( questName )
	if g_questManager then
		return g_questManager:cl_isQuestActive( questName )
	end
end

function QuestManager.Cl_IsQuestComplete( questName )
	if g_questManager then
		return g_questManager:cl_isQuestComplete( questName )
	end
end

function QuestManager.Cl_GetQuest( questName )
	if g_questManager then
		return g_questManager:cl_getQuest( questName )
	end
end

function QuestManager.Cl_UpdateQuestTracker()
	if g_questManager then
		g_questManager.cl.questTrackerDirty = true
	end
end

function QuestManager.sv_e_activateQuest( self, questName )
	local questUuid = self.sv.quests[questName]
	if questUuid ~= nil then
		self.sv.saved.activeQuests[questName] = sm.scriptableObject.createScriptableObject( questUuid )
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )
		self:sv_onEvent( QuestEvent.QuestActivated, { questName = questName } )
	else
		sm.log.error( questName .. " did not exist!" )
	end
end

function QuestManager.sv_e_abandonQuest( self, questName )
	local quest = self.sv.saved.activeQuests[questName]
	if quest then
		QuestManager.Sv_UnsubscribeAllEvents( quest )
		self.sv.saved.activeQuests[questName]:destroy()
		self.sv.saved.activeQuests[questName] = nil
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )
		self:sv_onEvent( QuestEvent.QuestAbandoned, { questName = questName } )
	end
end

function QuestManager.sv_e_completeQuest( self, questName )
	local completedQuest = self.sv.saved.activeQuests[questName]
	if completedQuest then
		self.network:sendToClients( "cl_n_questCompleted", questName )
		self.sv.saved.completedQuests[questName] = true
		self.sv.saved.activeQuests[questName]:destroy()
		self.sv.saved.activeQuests[questName] = nil
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )
		self:sv_onEvent( QuestEvent.QuestCompleted, { questName = questName } )
	end
end

function QuestManager.sv_onEvent( self, event, params )
	--print( "QuestManager - Event:", event, "params:", params )
	--print( "Subscribers:", self.sv.eventSubs[event] )
	if self.sv.eventSubs[event] ~= nil then
		for _, subCallback in ipairs( self.sv.eventSubs[event] ) do
			local sub = subCallback[1]
			local callbackName = subCallback[2]
			local data = { event = event, params = params }

			if not sm.exists( sub ) then
				sm.log.warning( "Tried to send callback to subscriber which does not exist: " .. tostring( sub ) )
				return
			end
			local t = type( sub )
			if t == "Harvestable" then
				sm.event.sendToHarvestable( sub, callbackName, data )
			elseif t == "ScriptableObject" then
				sm.event.sendToScriptableObject( sub, callbackName, data )
			elseif t == "Character" then
				sm.event.sendToCharacter( sub, callbackName, data )
			elseif t == "Tool" then
				sm.event.sendToTool( sub, callbackName, data )
			else
				sm.log.error( "Tried to send event to non-supported type in QuestCallbackHelper" )
			end
		end
	end
end

function QuestManager.sv_subscribeEvent( self, event, subscriber, callbackName )
	if self.sv.eventSubs[event] == nil then
		self.sv.eventSubs[event] = { { subscriber, callbackName } }
	else
		for _, subscriberCallback in ipairs( self.sv.eventSubs[event] ) do
			local sub = subscriberCallback[1]
			if sub == subscriber then
				print( "QuestManager - Already subscribed to event:", event, subscriber )
				return
			end
		end
		local numSubs = #self.sv.eventSubs[event]
		self.sv.eventSubs[event][numSubs + 1] = { subscriber, callbackName }
	end
end

function QuestManager.sv_unsubscribeEvent( self, event, subscriber )
	if self.sv.eventSubs[event] ~= nil then
		removeFromArray( self.sv.eventSubs[event], function( subscriberCallback )
			local sub = subscriberCallback[1]
			--if sub == subscriber then
			--	print( "QuestManager - Unsubscribed from event:", event, subscriber )
			--end
			return sub == subscriber
		end )
	end
end

function QuestManager.sv_unsubscribeAllEvents( self, subscriber )
	for event, _ in pairs( self.sv.eventSubs ) do
		self:sv_unsubscribeEvent( event, subscriber )
	end
end

function QuestManager.sv_isQuestActive( self, questName )
	return self.sv.saved.activeQuests[questName] ~= nil
end

function QuestManager.sv_isQuestComplete( self, questName )
	return self.sv.saved.completedQuests[questName] ~= nil
end

function QuestManager.sv_getQuest( self, questName )
	return self.sv.saved.activeQuests[questName]
end

function QuestManager.cl_updateQuestTracker( self )
	if not self.cl.trackerHud then
		return
	end

	for questName, object in pairs( self.cl.activeQuests ) do
		if sm.exists( object ) then
			if object.clientPublicData and object.clientPublicData.progressString then
				local isMainQuest = object.clientPublicData.isMainQuest
				local title = object.clientPublicData.title
				self.cl.trackerHud:trackQuest( questName, title, isMainQuest, {
					{ name = "step1", text = object.clientPublicData.progressString },
				} )
			end
		end

	end
	self.cl.questTrackerDirty = false
end

function QuestManager.client_onUpdate( self, dt )
	if self.cl.questTrackerDirty then
		self:cl_updateQuestTracker()
	end
end

function QuestManager.client_onRefresh( self )
end

function QuestManager.client_onClientDataUpdate( self, data )
	self.cl.activeQuests = data.activeQuests
	self.cl.completedQuests = data.completedQuests
	self.cl.questTrackerDirty = true
end

function QuestManager.cl_isQuestActive( self, questName )
	return self.cl.activeQuests[questName] ~= nil
end

function QuestManager.cl_isQuestComplete( self, questName )
	return self.cl.completedQuests[questName] ~= nil
end

function QuestManager.cl_getQuest( self, questName )
	return self.cl.activeQuests[questName]
end

function QuestManager.cl_n_questCompleted( self, questName )
	sm.gui.displayAlertText( "Quest completed!" )
	if self.cl.trackerHud then
			self.cl.trackerHud:untrackQuest( questName )
	end
end



--RAFT
function QuestManager.cl_getQuestProgressString( self, questName )
	if not self then
		self = g_questManager
	end

	if self.cl and self.cl.activeQuests[questName] and sm.exists(self.cl.activeQuests[questName]) then
		local data = self.cl.activeQuests[questName]:getClientPublicData()
		if data and data.progressString then
			return data.progressString
		end
	end
	return nil
end

function QuestManager.Sv_GotQuestLog(questName)
	self = g_questManager

	local quest = self.sv.saved.activeQuests[questName] or self.sv.saved.completedQuests[questName]
	if not quest then
		return false
	elseif type(quest) == "boolean" then
		return quest
	else
		return quest:getPublicData().log
	end
end

function QuestManager.Sv_UnlockRecipes( name )
	if g_questManager then
		sm.event.sendToScriptableObject( g_questManager.scriptableObject, "sv_unlockRecipes", name )
	end
end

function QuestManager.sv_unlockRecipes(self, name)
	local data = sm.json.open("$CONTENT_DATA/CraftingRecipes/" .. name .. ".json")
	local items = {}
	if data then
		for k, recipe in ipairs(data) do
			items[#items+1] = sm.uuid.new(recipe.itemId)
		end
	end
	if items then
		self.network:sendToClients("cl_unlock_recipes", items)
	end
end

function QuestManager.cl_unlock_recipes(self, items)
	for k, item in ipairs(items) do
		sm.gui.chatMessage(language_tag("Quest_ItemUnlock") .. sm.shape.getShapeTitle(item))
	end
end

function QuestManager.sv_e_onQuestEvent( self, data )
	if data.event == QuestEvent.QuestCompleted then
		if data.params.questName == "quest_raft_tutorial" then
			QuestManager.Sv_UnlockRecipes( "workbench" )
		elseif data.params.questName == "quest_rangerstation" then
			QuestManager.Sv_UnlockRecipes( "quest1" )
		elseif data.params.questName == "quest_radio_interactive" then
			QuestManager.Sv_UnlockRecipes( "questsail" )
		elseif data.params.questName == "quest_find_trader" then
			QuestManager.Sv_UnlockRecipes( "questpropeller" )
		elseif data.params.questName == "quest_deliver_vegetables" then
			QuestManager.Sv_UnlockRecipes( "questveggies" )
		elseif data.params.questName == "quest_deliver_fruits" then
			QuestManager.Sv_UnlockRecipes( "questharpoon" )
		elseif data.params.questName == "quest_deliver_fruits" then
			QuestManager.Sv_UnlockRecipes( "quest_warehouse" )	
		end
	end
end
