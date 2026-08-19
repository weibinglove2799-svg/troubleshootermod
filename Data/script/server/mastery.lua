--------------------------------------- CP propertys ---------------------------------------
function Get_Mastery_ApplyValue(mastery)
	local result = 0;
	result = mastery.BaseValue + mastery.Lv * mastery.MulValue;
	if mastery.MaxAmount > 0 then 
		result = math.min(result, mastery.MaxAmount);
	end
	return result;
end
--------------------------------------- EventHandler ---------------------------------------
function CalculatedProperty_MasteryCustomEventHandler(self, arg)
	local eventHandlers = {};

	local needInitializeEvent = false;
	for _, handler in ipairs(GetWithoutError(self, 'EventHandler') or {}) do
		if handler.Event == 'MasteryInitialized' then
			needInitializeEvent = true;
			break;
		end
	end
	if needInitializeEvent then
		table.insert(eventHandlers, {Event='MissionBegin', Script=Mastery_MasteryInitialize_MissionBegin, Order = 1});
		table.insert(eventHandlers, {Event='UnitPositionChanged_Self', Script=Mastery_MasteryInitialize_UnitPositionChanged, Order = 1});
		table.insert(eventHandlers, {Event='UnitCreated_Self', Script=Mastery_MasteryInitialize_UnitPositionChanged, Order = 1});
	end
	
	if self.InvalidateWhenBuffStateChanged then
		table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Mastery_SelfInvalidator, Order=1});
		table.insert(eventHandlers, {Event='BuffRemoved_Self', Script=Mastery_SelfInvalidator, Order=1});
	end

	return eventHandlers;
end

function Mastery_MasteryInitialize_MissionBegin(eventArg, mastery, owner, ds)
	if not mastery.NeedInitialize then
		return;
	end
	mastery.NeedInitialize = false;
	return Result_FireWorldEvent('MasteryInitialized', {Unit = owner, Mastery = mastery, AllowInvalidPosition = true}, owner);
end
function Mastery_MasteryInitialize_UnitPositionChanged(eventArg, mastery, owner, ds)
	if not mastery.NeedInitialize then
		return;
	end
	mastery.NeedInitialize = false;
	return Result_FireWorldEvent('MasteryInitialized', {Unit = owner, Mastery = mastery, AllowInvalidPosition = true}, owner);
end
function Mastery_SelfInvalidator(eventArg, mastery, owner, ds)
	return Result_InvalidateObject(owner);
end
-------------  utility --------------
function AddMasteryDamageChat(ds, object, mastery, damage)
	if mastery == nil or mastery.name == nil then
		LogAndPrint('[DataError] AddMasteryDamageChat Mastery is invalid - mastery:', mastery, ', object:', GetUnitDebugName(object), ', damage:', damage);
		Traceback();
		return;
	end
	local msg = 'MasteryDamage';
	local damageAmount = damage;
	if damage < 0 then
		msg = 'MasteryHeal';
		damageAmount = -damage;
	end
	ds:AddRelationMissionChat('MasteryEvent', msg, { ObjectKey = GetObjKey(object), MasteryType = mastery.name, Damage = damageAmount });
end
function _MasteryActivatedHelper(ds, mastery, target, eventType, needCam, refId, refOffset, noChat, battleEventType, chatTypePostFix)
	if mastery == nil or mastery.name == nil then
		LogAndPrint('[DataError] MasteryActivatedHelper Mastery is invalid - mastery:', mastery, ', target:', GetUnitDebugName(target), ', eventType:', eventType);
		Traceback();
		return;
	end
	local targetKey = GetObjKey(target);
	local invoke = ds:UpdateBattleEvent(targetKey, battleEventType, { Mastery = mastery.name });
	if needCam then
		local visible = ds:EnableIf('TestObjectVisibleAndAlive', targetKey);
		local turnCamTest = ds:EnableIf('TestDisableTurnCamTargetKey', targetKey);
		ds:Connect(turnCamTest, visible, -1);
		local cam = ds:ChangeCameraTarget(targetKey, '_SYSTEM_', false);
		ds:Connect(cam, turnCamTest, -1);
		ds:Connect(invoke, cam, 0.5);
		invoke = cam;
	end
	if not noChat then
		ds:AddMissionChat(GetMasteryEventKey(target)..chatTypePostFix, 'MasteryEvent', {ObjectKey = targetKey, MasteryType = mastery.name, EventType = eventType});
	end
	if refId then
		ds:Connect(invoke, refId, refOffset);
	end
end
function MasteryActivatedHelper(ds, mastery, target, eventType, needCam, refId, refOffset, noChat)
	_MasteryActivatedHelper(ds, mastery, target, eventType, needCam, refId, refOffset, noChat, 'MasteryInvoked', '');
end
function BestFriendMasteryActivatedHelper(ds, mastery, target, eventType, needCam, refId, refOffset, noChat)
	_MasteryActivatedHelper(ds, mastery, target, eventType, needCam, refId, refOffset, noChat, 'MasteryInvoked_BestFriend', 'BF');
end
function MasteryDamageHelper(ds, mastery, target, damage, needCam, refId, refOffset, noChat)
	if mastery == nil or mastery.name == nil then
		LogAndPrint('[DataError] MasteryDamageHelper Mastery is invalid - mastery:', mastery, ', target:', GetUnitDebugName(target), ', damage:', damage);
		Traceback();
		return;
	end
	local targetKey = GetObjKey(target);
	local invoke = ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery.name });
	if needCam then
		local visible = ds:EnableIf('TestObjectVisibleAndAlive', targetKey);
		local cam = ds:ChangeCameraTarget(targetKey, '_SYSTEM_', false);
		ds:Connect(cam, visible, -1);
		ds:Connect(invoke, cam, 0.5);
		invoke = cam;
	end
	if not noChat then
		AddMasteryDamageChat(ds, target, mastery, damage);
	end
	if refId then
		ds:Connect(invoke, refId, refOffset);
	end
end
function IsAvailableAbility(owner, ability)
	return AbilityUseableCheck(owner, ability, {}, true, nil, nil, true) == 'Able';
end
------------------------------------------------------------------------------
-- 이벤트 공용
-------------------------------------------------------------------------------
-- DuplicateApplyChecker 초기화
function MasteryCommon_ResetDuplicateApplyChecker(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
local AddMessageRemover = function(b) b.UseAddedMessage = false; end;
------------------------------------------------------------------------------
-- 마스터리 초기화 [MasteryInitialized]
-------------------------------------------------------------------------------
-- 선조의 기록
function Mastery_HeredityExpression_Initialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local beastTypeCls = GetBeastTypeClassFromObject(owner);
	LogAndPrint('Mastery_HeredityExpression_Initialized', SafeIndex(beastTypeCls, 'name'));
	if beastTypeCls == nil then
		LogAndPrint('Mastery_HeredityExpression_Initialized', 'ERR', 'Can\'t get beastType from owner', owner.name);
		return;
	end
	local _, _, candidates_Nature, _, candidates_Gene, candidates_ESP = GetBeastUniqueMasteryCandidate(beastTypeCls);

	local masteryTable = GetMastery(owner);
	candidates_Gene = table.filter(candidates_Gene, function(m)
		return not GetMasteryMastered(masteryTable, m);
	end);
	candidates_Nature = table.filter(candidates_Nature, function(m)
		return not GetMasteryMastered(masteryTable, m);
	end);
	candidates_ESP = table.filter(candidates_ESP, function(m)
		return not GetMasteryMastered(masteryTable, m);
	end);

	local picker = RandomPicker.new(false);
	picker:addChoiceMulti(1, candidates_Gene);

	local m = picker:pick();
	--mastery.RefMastery = m;

	local actions = {};
	local addedMasteryNames = {};

	local refKeys = {'RefMastery', 'RefMastery2', 'RefMastery3', 'RefMastery4'};
	local AddUpdateMastery = function(hostMastery, index, addMastery)
		if index <= #refKeys then
			hostMastery[refKeys[index]] = addMastery;
		end
		table.insert(actions, Result_UpdateMastery(owner, addMastery, 1));
		table.insert(addedMasteryNames, addMastery);
	end

	local mIndex = 1;
	for i = 1, mastery.ApplyAmount do
		AddUpdateMastery(mastery, mIndex, m);
		mIndex = mIndex + 1;
	end

	-- 선조 계승
	local mastery_AncestorsSuccession = GetMasteryMastered(GetMastery(owner), 'AncestorsSuccession');
	if mastery_AncestorsSuccession then
		mIndex = 1;
		for i = 1, mastery_AncestorsSuccession.ApplyAmount do
			local gm = picker:pick();
			if gm then
				AddUpdateMastery(mastery_AncestorsSuccession, mIndex, gm);
				mIndex = mIndex + 1;
			end
		end
		-- 본성 각성 부분
		local pickerNature = RandomPicker.new(false);
		pickerNature:addChoiceMulti(1, candidates_Nature);
		for i = 1, mastery_AncestorsSuccession.ApplyAmount2 do
			local nm = pickerNature:pick();
			if nm then
				AddUpdateMastery(mastery_AncestorsSuccession, mIndex, nm);
				mIndex = mIndex + 1;
			end
		end
		-- 이능력 유전자 부분
		local pickerESP = RandomPicker.new(false);
		pickerESP:addChoiceMulti(1, candidates_ESP);
		for i = 1, mastery_AncestorsSuccession.ApplyAmount3 do
			local em = pickerESP:pick();
			if em then
				AddUpdateMastery(mastery_AncestorsSuccession, mIndex, em);
				mIndex = mIndex + 1;
			end
		end
	end
	-- HeredityExpression으로 추가된 마스터리들의 MasteryInitialized 수동 발화
	-- Result_UpdateMastery 액션이 먼저 실행된 후 콜백이 실행되도록 Result_DirectingScript 사용
	if #addedMasteryNames > 0 then
		local ownerRef = owner;
		local masteryNamesToInit = {unpack(addedMasteryNames)};
		table.insert(actions, Result_DirectingScript(function(mid, ds, args)
			local initActions = {};
			local masteryTable = GetMastery(ownerRef);
			for _, masteryName in ipairs(masteryNamesToInit) do
				local addedMastery = GetMasteryMastered(masteryTable, masteryName);
				if addedMastery and addedMastery.NeedInitialize then
					addedMastery.NeedInitialize = false;
					table.insert(initActions, Result_FireWorldEvent('MasteryInitialized', {Unit = ownerRef, Mastery = addedMastery, AllowInvalidPosition = true}, ownerRef));
				end
			end
			return unpack(initActions);
		end));
	end
	return unpack(actions);
end
-- 전투 태세
function Mastery_StanceChange_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffName = mastery.Buff.name;
	-- 능숙한 전투 태세
	local mastery_ExpertStanceChange = GetMasteryMastered(GetMastery(owner), 'ExpertStanceChange');
	if mastery_ExpertStanceChange then
		buffName = mastery_ExpertStanceChange.Buff.name;
	end
	return Result_AddBuff(owner, owner, buffName, 1, AddMessageRemover);
end
-- 디스크 레이돔
function Mastery_Module_DiskRadom_Initialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local masteryTable = GetMastery(owner);
	local actions = {};
	local buffList = {};
	-- 디스크 레이돔
	local buffType = 'InformationConstruction_Aura';
	-- 강화 디스크 레이돔
	if GetMasteryMastered(masteryTable, 'Module_ReinforcedDiskRadom') then
		buffType = 'InformationSharing_Aura';
	end
	-- 정보 제어 프로그램
	if GetMasteryMastered(masteryTable, 'Module_InformationControl') then
		buffType = buffType..'_Range6';
	end
	table.insert(actions, Result_AddBuff(owner, owner, buffType, 1, nil, true));
	table.insert(buffList, buffType);
	-- 수색 강화 프로그램
	if GetMasteryMastered(masteryTable, 'Module_EnhancedSearch') then
		local buffType2 = 'Module_EnhancedSearch';
		-- 정보 제어 프로그램
		if GetMasteryMastered(masteryTable, 'Module_InformationControl') then
			buffType2 = buffType2..'_Range6';
		end
		table.insert(actions, Result_AddBuff(owner, owner, buffType2, 1, nil, true));
		table.insert(buffList, buffType2);
	end
	-- 셧 다운 시, 해제 후 복원용
	SetInstantProperty(owner, mastery.name, buffList);
	return unpack(actions);
end
-- 해체 전문가
function Mastery_DismantlingSpecialist_Initialized(eventArg, mastery, owner, ds)
	SetInstantProperty(owner, 'DismantlingSpecialist', true);
end
-- 정보 교란
function Mastery_InformationDistortion_Initalized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffType = 'InformationDistortion_Aura';
	if GetMasteryMastered(GetMastery(owner), 'InformationSpecialist') then
		buffType = 'InformationDistortion_Aura_Range6';
	end
	return Result_AddBuff(owner, owner, buffType, 1, nil, true);
end
-- 정보 교란기
function Mastery_Module_InformationJammer_Initialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local masteryTable = GetMastery(owner);
	local buffType = 'InformationDistortion_Aura';
	-- 강화 정보 교란기
	if GetMasteryMastered(masteryTable, 'Module_ReinforcedInformationJammer') then
		buffType = 'InformationFalsification_Aura';
	end
	-- 정보 제어 프로그램
	if GetMasteryMastered(masteryTable, 'Module_InformationControl') then
		buffType = buffType..'_Range6';
	end
	-- 셧 다운 시, 해제 후 복원용
	SetInstantProperty(owner, mastery.name, {buffType});
	return Result_AddBuff(owner, owner, buffType, 1, nil, true);
end
-- 지식의 보고
function Mastery_TreasureHouseOfKnowledge_Initialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local company = GetCompany(owner);
	if company == nil then
		return;
	end
	local prevTHOK = GetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount') or 0;
	SetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount', prevTHOK + mastery.ApplyAmount);
end
-- 보물지도
function Mastery_TreasureMap_Initialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local company = GetCompany(owner);
	if company == nil then
		return;
	end
	local prevTHOK = GetCompanyInstantProperty(company, 'TreasureMapAmount') or 0;
	SetCompanyInstantProperty(company, 'TreasureMapAmount', prevTHOK + mastery.ApplyAmount);
end
-- 카리스마
function Mastery_Charisma_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffType = 'Charisma';
	local masteryTable = GetMastery(owner);
	-- 혁명가
	if GetMasteryMastered(masteryTable, 'Revolutionist') then
		buffType = 'Charisma_Range6';
	end
	-- 명장, 내 노래를 들어봐!, 힘내세요!
	if GetMasteryMasteredList(masteryTable, {'CharismaVeteran', 'ListenToMySong', 'SongForYou'}) then
		local auraRange = SafeIndex(GetClassList('Buff'), buffType, 'AuraRange');
		if auraRange then
			SetInstantProperty(owner, 'CharismaRange', auraRange);
		end
	end
	return Result_AddBuff(owner, owner, buffType, 1, nil, true, nil, nil, {Type = 'Charisma'});
end
-- 억압
function Mastery_Oppression_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffType = 'Oppression';
	local masteryTable = GetMastery(owner);
	-- 지배자
	local mastery_Overload = GetMasteryMastered(masteryTable, 'Overlord');
	-- 검은 마녀
	local mastery_BlackWitch = GetMasteryMastered(masteryTable, 'BlackWitch');
	
	if mastery_Overload then
		if mastery_BlackWitch then
			buffType = 'Oppression_Heavy_Range6';
		else
			buffType = 'Oppression_Range6';
		end
	elseif mastery_BlackWitch then
		buffType = 'Oppression_Heavy';
	end
	-- 눼에에굴!!
	if GetMasteryMasteredList(masteryTable, {'OppressionSong'}) then
		local auraRange = SafeIndex(GetClassList('Buff'), buffType, 'AuraRange');
		if auraRange then
			SetInstantProperty(owner, 'OppressionRange', auraRange);
		end
	end
	return Result_AddBuff(owner, owner, buffType, 1, nil, true, nil, nil, {Type = 'Oppression'});
end
-- 악취
function Mastery_BadSmell_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	return Result_AddBuff(owner, owner, 'BadSmell_Aura', 1, nil, true, nil, nil, {Type = 'BadSmell'});
end
-- 향기
function Mastery_GoodSmell_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	return Result_AddBuff(owner, owner, 'GoodSmell_Aura', 1, nil, true, nil, nil, {Type = 'GoodSmell'});
end
-- 발광
function Mastery_Illumination_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	table.insert(actions, Result_AddBuff(owner, owner, 'Illumination_Aura', 1, nil, true, nil, nil, {Type = 'Illumination'}));
	table.insert(actions, Result_AddBuff(owner, owner, 'Illumination_Aura_Exposure', 1, nil, true, nil, nil, {Type = 'Illumination'}));
	return unpack(actions);
end
-- 함정시스템
function Mastery_TrapSystem_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local mvrKey = string.format('TRAP_AREA:%s', GetObjKey(owner));
	RegisterConnectionRestoreRoutine(GetMission(owner), mvrKey, function(ds)
		ds:MissionVisualRange_AddCustom(mvrKey, true, GetPosition(owner), GetObjKey(owner), 'Sphere2_Trap_Ally','Sphere2_Trap');
	end);
	ds:MissionVisualRange_AddCustom(mvrKey, true, GetPosition(owner), GetObjKey(owner), 'Sphere2_Trap_Ally','Sphere2_Trap');
	
	local mvaKey = string.format('TRAP_CLOCKING:%s', GetObjKey(owner));
	RegisterConnectionRestoreRoutine(GetMission(owner), mvaKey, function(ds)
		ds:MissionVisualArea_AddCustom(mvaKey, GetPosition(owner), 'Particles/Dandylion/EmptyDistortion', true, nil);
	end);
	ds:MissionVisualArea_AddCustom(mvaKey, GetPosition(owner), 'Particles/Dandylion/EmptyDistortion', true, nil);
	
	local trapHost = GetExpTaker(owner);
	-- 괴수 사냥꾼 - 2 세트
	local mastery_MonsterHunterSet2 = GetMasteryMastered(GetMastery(trapHost), 'MonsterHunterSet2');
	if mastery_MonsterHunterSet2 then
		local allyRange = 'Sphere3_Trap_Assist_Dot';
		local enemyRange = 'Sphere3_Trap_Dot';
		local mvrKey2 = string.format('TRAP_AREA_APPLY:%s', GetObjKey(owner));
		RegisterConnectionRestoreRoutine(GetMission(owner), mvrKey2, function(ds)
			ds:MissionVisualRange_AddCustom(mvrKey2, true, GetPosition(owner), GetObjKey(owner), allyRange, enemyRange);
		end);
		ds:MissionVisualRange_AddCustom(mvrKey2, true, GetPosition(owner), GetObjKey(owner), allyRange, enemyRange);	
	end	
end
-- 사냥꾼의 일상
function Mastery_LifeOfHunter_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	SetInstantProperty(owner, 'DailyHuntingNow', true);
end
-- 어빌리티를 사용하는 버프 토글형 특성
function Mastery_CommonToggleBuff_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	return Result_AddBuff(owner, owner, mastery.Buff.name, 1, AddMessageRemover);
end
-- 저격수의 눈
function Mastery_SniperEye_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffName = mastery.Buff.name;
	-- 명사수의 눈
	local mastery_BestSniperEye = GetMasteryMastered(GetMastery(owner), 'BestSniperEye');
	if mastery_BestSniperEye then
		buffName = mastery_BestSniperEye.SubBuff.name;
	end
	return Result_AddBuff(owner, owner, buffName, 1, AddMessageRemover);
end
-- 사냥의 마음가짐
function Mastery_HeartOfHunter_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffName = mastery.Buff.name;
	-- 능숙한 사냥
	local mastery_SkilledHunting = GetMasteryMastered(GetMastery(owner), 'SkilledHunting');
	if mastery_SkilledHunting then
		buffName = mastery_SkilledHunting.SubBuff.name;
	end
	return Result_AddBuff(owner, owner, buffName, 1, AddMessageRemover);
end
-- 전사의 후예
function Mastery_DescendantOfWarrior_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffName = mastery.Buff.name;
	local mastery_SuccessorOfWarrior = GetMasteryMastered(GetMastery(owner), 'SuccessorOfWarrior');
	if mastery_SuccessorOfWarrior then
		buffName = mastery_SuccessorOfWarrior.Buff.name;
	end
	return Result_AddBuff(owner, owner, buffName, 1, AddMessageRemover);
end
-- 수호자의 후예
function Mastery_DescendantOfGuardian_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffName = mastery.Buff.name;
	local mastery_SuccessorOfGuardian = GetMasteryMastered(GetMastery(owner), 'SuccessorOfGuardian');
	if mastery_SuccessorOfGuardian then
		buffName = mastery_SuccessorOfGuardian.Buff.name;
	end
	return Result_AddBuff(owner, owner, buffName, 1, AddMessageRemover);
end
-- 사냥꾼 인장
function Mastery_Amulet_Hunter_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	return Result_AddBuff(owner, owner, mastery.Buff.name, 1, AddMessageRemover);
end
-- 멍고! 멍고!
function Mastery_MunggoMunggo_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffName = mastery.Buff.name;
	-- 멍고! 멍고!! 멍고!!!
	local mastery_SkilledHunting = GetMasteryMastered(GetMastery(owner), 'MunggoMunggoMunggo');
	if mastery_SkilledHunting then
		buffName = mastery_SkilledHunting.SubBuff.name;
	end
	return Result_AddBuff(owner, owner, buffName, 1, AddMessageRemover);
end

-- 특성 불살
function Mastery_DoNotKill_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, nil, AddMessageRemover);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'MissionBegin'});
	return unpack(actions);
end
-- 특성 무법자
function Mastery_Outlaw_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, nil, AddMessageRemover);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'MissionBegin'});
	return unpack(actions);
end
-- 특성 별이 빛나는 밤
function Mastery_StarryNight_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	local mission = GetMission(owner);
	local isStarry = (mission.Weather.name == 'Windy' or mission.Weather.name == 'Clear');
	local isNight = (mission.MissionTime.name == 'Evening' or mission.MissionTime.name == 'Night');
	if isStarry and isNight then
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, nil, AddMessageRemover);
	else
		InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, nil, AddMessageRemover);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'MissionBegin'});
	return unpack(actions);
end
-- 특성 방어진
function Mastery_DefenseCordon_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	local masteryTable = GetMastery(owner);
	local buffName = 'DefenseCordon_Aura';
	InsertBuffActions(actions, owner, owner, buffName, 1, nil, AddMessageRemover);
	return unpack(actions);
end
-- 특성 생명의 기원
function Mastery_OriginOfLife_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	local masteryTable = GetMastery(owner);
	local buffName = 'OriginOfLife_Aura';
	-- 빛의 아이
	local mastery_ChildOfLight = GetMasteryMastered(masteryTable, 'ChildOfLight');
	if mastery_ChildOfLight then
		buffName = 'OriginOfLife_Aura_Range6';
	end
	InsertBuffActions(actions, owner, owner, buffName, 1, nil, AddMessageRemover);
	return unpack(actions);
end
-- 특성 성스러운 방패
function Mastery_HolyShield_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	local masteryTable = GetMastery(owner);
	local buffName = GetHolyShieldAuraBuffName(owner);
	InsertBuffActions(actions, owner, owner, buffName, 1, nil, AddMessageRemover);
	-- 빛의 아이
	local mastery_ChildOfLight = GetMasteryMastered(masteryTable, 'ChildOfLight');
	if mastery_ChildOfLight then
		local buffName = 'WillOfLight_Aura';
		-- 성스러운 방패와 범위가 같아야 하므로, 성자에 의한 범위 확장도 같이 적용된다.
		local mastery_Saint = GetMasteryMastered(masteryTable, 'Saint');
		if mastery_Saint then
			buffName = 'WillOfLight_Aura_Range6';
		end
		InsertBuffActions(actions, owner, owner, buffName, 1, nil, AddMessageRemover);
	end
	return unpack(actions);
end
function GetHolyShieldAuraBuffName(owner)
	local masteryTable = GetMastery(owner);
	local buffName = 'HolyShield_Aura';
	-- 성자 (범위 확장)
	local mastery_Saint = GetMasteryMastered(masteryTable, 'Saint');
	-- 천상의 방패 (버프 교체)
	local mastery_HeavenShield = GetMasteryMastered(masteryTable, 'HeavenShield');
	if mastery_HeavenShield then
		if mastery_Saint then
			buffName = 'HeavenShield_Aura_Range6';
		else
			buffName = 'HeavenShield_Aura';
		end
	elseif mastery_Saint then
		buffName = 'HolyShield_Aura_Range6';
	end
	return buffName;
end
-- 특성 살수의 인장
function Mastery_Amulet_Killer_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true, AddMessageRemover);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'MasteryInitialized'});
	return unpack(actions);
end
-- 수리 가능 오브젝트
function Mastery_RepairableObject_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	return Result_UpdateInteraction(owner, 'Repair', true);
end
-- 야샤 알집
function Mastery_HatchedObjectYasha_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, 'HatchedObjectYasha', 1, true, AddMessageRemover);
	return unpack(actions);
end
-- 항동결 수액
function Mastery_AntiFreezingInfusionSolution_Initalized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffName = mastery.SubBuff.name;
	local buffLv = mastery.ApplyAmount;
	local masteryTable = GetMastery(owner);
	-- 고급 항동결 수액
	local mastery_AntiFreezing = GetMasteryMastered(masteryTable, 'AntiFreezing');
	if mastery_AntiFreezing then
		buffLv = buffLv + mastery_AntiFreezing.ApplyAmount;
	end
	-- 항동결 부작용
	local mastery_AntiFreezingSideEffect = GetMasteryMastered(masteryTable, 'AntiFreezingSideEffect');
	if mastery_AntiFreezingSideEffect then
		buffLv = buffLv + mastery_AntiFreezingSideEffect.ApplyAmount;
	end

	local actions = {};
	InsertBuffActions(actions, owner, owner, buffName, buffLv, true, nil, nil, {Type = mastery.name});
	return unpack(actions);
end
-- 긍정적인 마음
function Mastery_PositiveMind_Initalized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true, AddMessageRemover);
	return unpack(actions);
end
-- 승격
function Mastery_Promotion_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true, AddMessageRemover);
	return unpack(actions);
end
-----------------------------------------------------------------------
-- 유닛 사망 [UnitDead]
-------------------------------------------------------------------------------
-- 사체 처리
function Mastery_DeadDisposal_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or not owner.TurnState.TurnEnded
		or mastery.CountChecker >= mastery.ApplyAmount
		or not IsAdjacentDistance(GetPosition(owner), GetPosition(eventArg.Unit))
		or not (eventArg.Unit.Race.name == 'Human' or eventArg.Unit.Race.name == 'Beast') then
		return;
	end

	ds:LookPos(GetObjKey(owner), GetPosition(eventArg.Unit), nil, nil, nil, true--[[no_cover]]);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	ds:PlayAni(GetObjKey(owner), 'Atk9', false, -1, true--[[no_wait]]);

	local actions = {};
	AddActionRestoreHPForDS(actions, owner, owner, owner.MaxHP * mastery.ApplyAmount3 / 100, ds);
	mastery.CountChecker = mastery.CountChecker + 1;
	-- 시체 청소부
	local mastery_CorpseEater = GetMasteryMastered(GetMastery(owner), 'CorpseEater');
	if mastery_CorpseEater then
		MasteryActivatedHelper(ds, mastery_CorpseEater, owner, 'UnitDead');
		AddRandomFoodBuffAction(actions, owner, owner, 1);
	end
	return unpack(actions);
end
-- 현장 위기 관리
function Mastery_FieldCrisisManagerment_UnitDead(eventArg, mastery, owner, ds)
	if SafeIndex(owner, 'Affiliation', 'name') == nil
		or not IsTeamOrAlly(owner, eventArg.Unit)
		or SafeIndex(eventArg.Unit, 'Affiliation', 'name') ~= SafeIndex(owner, 'Affiliation', 'name')
		or not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end

	local nearAllies = Linq.new(GetNearObject(owner, mastery.ApplyAmount + 0.4))
		:where(function(o) return IsTeamOrAlly(owner, o) and SafeIndex(owner, 'Affiliation', 'name') == SafeIndex(o, 'Affiliation', 'name') end)
		:toList();

	local actions = {};
	for _, ally in ipairs(nearAllies) do
		InsertBuffActions(actions, owner, ally, mastery.Buff.name, 1, true);
		AddActionApplyActForDS(actions, owner, ally, -mastery.ApplyAmount2, ds, 'Friendly');
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	return unpack(actions);
end
-- 분노의 보복
function Mastery_RevengeOnRage_UnitDead(eventArg, mastery, owner, ds)
	if not IsBestFriendMasteryTarget(owner, eventArg.Unit, mastery.name)
		or eventArg.Killer == nil
		or not IsEnemy(owner, eventArg.Killer)
		or not IsInSight(owner, GetPosition(eventArg.Unit), true)
		or GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	if eventArg.DamageInfo.damage_type == 'Ability' then
		local ability = eventArg.DamageInfo.damage_invoker;
		if ability and ability.RelocatorMoveType == 'Flash' then
			return;
		end
	end
	
	local actions = {};
	BestFriendMasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false, true, 0.75);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	local killerKey = GetObjKey(eventArg.Killer);
	table.insert(actions, Result_DirectingScript(function(mid, ds, arg)
		return Mastery_TryAttackIfAvailable(owner, {[killerKey] = true}, {ReactionAbility = true, Inevitable = true});
	end, nil, true));
	table.insert(actions, Result_FireWorldEvent('BestFriendMasteryActivated', {Unit = owner, Target = eventArg.Unit, Mastery = mastery.name}, nil, true));
	return unpack(actions);
end
function Mastery_Skull_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or GetTeam(eventArg.Unit) ~= GetTeam(owner)
		or not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end
	
	local actions = {};
	local subAct = mastery.ApplyAmount;
	AddActionApplyActForDS(actions, owner, owner, -subAct, ds, 'Friendly');
	if owner.Act < subAct then
		mastery.DuplicateApplyChecker = 1;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	return unpack(actions);
end
-- 이타주의자
function Mastery_Altruist_UnitDead(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or GetTeam(owner) ~= GetTeam(eventArg.Killer)
		or owner == eventArg.Killer
		or not IsInSight(owner, GetPosition(eventArg.Killer), true)
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	local actions = {};
	local applyAct = -mastery.ApplyAmount;	
	if PositionInRange(CalculateRange(owner, GetClassList('Mastery').TeamPlayer.Range, GetPosition(owner)), GetPosition(eventArg.Killer)) then	
		applyAct = applyAct - mastery.ApplyAmount;
	end
	AddActionApplyActForDS(actions, owner, owner, applyAct, ds, 'Friendly');
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 지식의 보고
function Mastery_TreasureHouseOfKnowledge_UnitDead(eventArg, mastery, owner, ds)
	local company = GetCompany(owner);
	if not company then
		return;
	end
	local prevTHOK = GetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount');
	SetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount', prevTHOK - mastery.ApplyAmount);
end
-- 보물지도
function Mastery_TreasureMap_UnitDead(eventArg, mastery, owner, ds)
	local company = GetCompany(owner);
	if not company then
		return;
	end
	local prevTHOK = GetCompanyInstantProperty(company, 'TreasureMapAmount');
	SetCompanyInstantProperty(company, 'TreasureMapAmount', prevTHOK - mastery.ApplyAmount);
end
-- 사냥꾼과 사냥개
function Mastery_HunterAndHuntingDog_UnitDead(eventArg, mastery, owner, ds)
	local hostKey = GetInstantProperty(eventArg.Killer, 'SummonMaster');
	local damageFlag = SafeIndex(eventArg, 'DamageInfo', 'Flag');
	if hostKey ~= GetObjKey(owner)
		or (SafeIndex(damageFlag, 'AttackWithBeast') == nil or SafeIndex(damageFlag, 'InvokedByTrap') == nil) then
		return;
	end
	
	local actions = {};
	for _, obj in ipairs(GetNearObject(eventArg.Unit, mastery.ApplyAmount)) do
		if IsEnemy(owner, obj) and not IsDead(obj) then
			InsertBuffActions(actions, owner, obj, mastery.Buff.name, 1, true);
		end
	end
	if #actions <= 0 then
		return;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	return unpack(actions);
end
-- 함정 시스템
function Mastery_TrapSystem_UnitDead(eventArg, mastery, owner, ds)
	local mvrKey = string.format('TRAP_AREA:%s', GetObjKey(owner));
	UnregisterConnectionRestoreRoutine(GetMission(owner), mvrKey);
	ds:MissionVisualRange_AddCustom(mvrKey, false, nil, GetObjKey(owner));
	
	local mvaKey = string.format('TRAP_CLOCKING:%s', GetObjKey(owner));
	UnregisterConnectionRestoreRoutine(GetMission(owner), mvaKey);
	ds:MissionVisualArea_AddCustom(mvaKey, nil, nil, false);
	
	local trapHost = GetExpTaker(owner);
	-- 괴수 사냥꾼 - 2 세트
	local mastery_MonsterHunterSet2 = GetMasteryMastered(GetMastery(trapHost), 'MonsterHunterSet2');
	if mastery_MonsterHunterSet2 then
		local mvrKey2 = string.format('TRAP_AREA_APPLY:%s', GetObjKey(owner));
		UnregisterConnectionRestoreRoutine(GetMission(owner), mvrKey2);
		ds:MissionVisualRange_AddCustom(mvrKey2, false, nil, GetObjKey(owner));
	end
	
	return Result_ChangeTeam(owner, '_dummy', false);
end
-- 사후 탈피
function Mastery_MoltAfterDeath_UnitDead(eventArg, mastery, owner, ds)
	if GetBuff(owner, mastery.SubBuff.name) then
		return;
	end

	local limit = 1;
	if mastery.DuplicateApplyChecker >= limit then
		return;
	end

	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Sleep(1.5);
	local resurrectID = ds:Resurrect(objKey, false, true);
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
	ds:Connect(resurrectID, particleID, 3.8);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	local restoreAmount = mastery.ApplyAmount2;
	local hpUpdate = Result_PropertyUpdated('HP', math.floor(owner.MaxHP * restoreAmount / 100), owner, true);
	hpUpdate.sequential = true;
	
	local actions = {};
	table.insert(actions, Result_Resurrect(owner, 'Normal', true, mastery, true));
	table.insert(actions, Result_TurnEnd(owner, false));
	table.insert(actions, Result_AddBuff(owner, owner, mastery.Buff.name, 1, nil, true));
	table.insert(actions, Result_AddBuff(owner, owner, mastery.SubBuff.name, 1, nil, true));
	table.insert(actions, hpUpdate);
	-- 단단한 허물
	local mastery_HeavyMoltAfterDeath = GetMasteryMastered(GetMastery(owner), 'HeavyMoltAfterDeath');
	if mastery_HeavyMoltAfterDeath then
		MasteryActivatedHelper(ds, mastery_HeavyMoltAfterDeath, owner, 'UnitDead_Self');
		InsertBuffActions(actions, owner, owner, mastery_HeavyMoltAfterDeath.Buff.name, 1, true);
	end
	return unpack(actions);
end
-- 특성 두 번째 심장.
function Mastery_SecondHeart_UnitDead(eventArg, mastery, owner, ds)
	if GetBuff(owner, mastery.Buff.name) then
		return;
	end
	local limit = 1;
	-- 세번째 심장
	local mastery_ThirdHeart = GetMasteryMastered(GetMastery(owner), 'ThirdHeart');
	if mastery_ThirdHeart then
		limit = mastery_ThirdHeart.ApplyAmount;
	end
	if mastery.DuplicateApplyChecker >= limit then
		return;
	end
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if mastery_ThirdHeart then
		ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery_ThirdHeart.name });
	end	
	ds:Sleep(1.5);
	local resurrectID = ds:Resurrect(objKey);
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
	ds:Connect(resurrectID, particleID, 3.8);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	if mastery_ThirdHeart then
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery_ThirdHeart.name, EventType = 'UnitDead'});
	end
	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	local restoreAmount = mastery.ApplyAmount;
	if mastery_ThirdHeart then
		restoreAmount = mastery_ThirdHeart.ApplyAmount2;
	end
	local hpUpdate = Result_PropertyUpdated('HP', math.floor(owner.MaxHP * restoreAmount / 100), owner, true);
	hpUpdate.sequential = true;
	
	local actions = {};
	table.insert(actions, Result_Resurrect(owner, 'Normal', true, mastery));
	table.insert(actions, Result_AddBuff(owner, owner, mastery.Buff.name, 1));
	table.insert(actions, hpUpdate);
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	return unpack(actions);
end
-- 특성 : 불사조
function Mastery_Phoenix_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or GetBuff(owner, mastery.Buff.name) then
		return;
	end
	
	-- 1. 화염 속성 초능력자가 아니면 작동 안함.
	if not owner.ESP and owner.ESP.name ~= 'Fire' then
		LogAndPrint(string.format('[%s]>>[%s:%s] Failed to rebirth with Phoenix (not fire ESP user)', GetMissionID(owner), owner.name, GetObjKey(owner)));
		return;
	end
	-- 2. SP가 없을 경우.
	if owner.MaxSP == 0 or owner.SP == 0 then
		-- 불사조 특성의 기능적 특성상 발동 하지 않는 조건이 컨트롤하기 어렵고 가끔씩 실수로 등장하기 때문에 로그를 따로 남겨둘
		LogAndPrint(string.format('[%s]>>[%s:%s] Failed to rebirth with Phoenix (no SP)', GetMissionID(owner), owner.name, GetObjKey(owner)));
		return;
	end
	
	LogAndPrint(string.format('[%s]>>[%s:%s] Succeed to rebirth with Phoenix', GetMissionID(owner), owner.name, GetObjKey(owner)));
	
	local resetSP = true;	
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false, false, 0.5);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Sleep(1.5);
	local resurrectID = ds:Resurrect(objKey);	
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/Pheonix', 5);
	ds:Connect(resurrectID, particleID, 3.8);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	if owner.Info.name == 'Carter' and GetCompany(owner) then
		ds:UpdateAchievement('AbilityCarter', true, GetTeam(owner));
	end
	local hpUpdate = Result_PropertyUpdated('HP', math.max(1, math.min(owner.MaxHP, owner.SP * mastery.ApplyAmount)), owner, true);
	
	local masteryTable = GetMastery(owner);
	local mastery_LastFlame = GetMasteryMastered(masteryTable, 'LastFlame');
	if mastery_LastFlame then
		resetSP = false;
	end
	hpUpdate.sequential = true;
	
	local af = MasteryActionFactory.new(ds);
	af:AddAction(Result_Resurrect(owner, 'Normal', resetSP, mastery));
	af:AddAction(Result_AddBuff(owner, owner, mastery.Buff.name, 1, nil, true));
	af:AddAction(hpUpdate);

	-- 복수의 불꽃
	af:AddSynergyMasteryAction(owner, 'RevengeFlame', function(mastery_RevengeFlame)
		af:AddAction(Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
		if not owner.TurnState.TurnEnded then
			for _, action in ipairs({GetInitializeTurnActions(owner)}) do
				af:AddAction(action);
			end;
		end
	end);

	-- 열광하는 방화광
	af:AddSynergyMasteryAction(owner, 'EnthusiasticPyromaniac', function(sm)
		af:UpdateAbilityCool(owner, 0, function(curAbility)
			return curAbility.SubType == 'Fire';
		end);
	end);
	
	return af:UnpackActions('UnitDead_Self');
end
-- 긴급 구조 프로그램
function Mastery_Module_EmergencyRescue_UnitDead_Self(eventArg, mastery, owner, ds)
	if GetInstantProperty(owner, 'EmergencyRescueTarget') == nil then
		return;
	end
	-- 긴급 구조하러 가는중에 죽음..
	mastery.CountChecker = 1;
	local ret = Result_FireWorldEvent('EmergencyRescueCompleted', {Receptionist = owner, Target = GetInstantProperty(owner, 'EmergencyRescueTarget'), Succeed = false});
	SetInstantProperty(owner, 'EmergencyRescueTarget', nil);
	
	return ret;
end
-- 긴급 구조 프로그램
function Mastery_Module_EmergencyRescue_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or GetRelation(owner, eventArg.Unit) ~= 'Team'
		or eventArg.Unit.Obstacle then
		return;
	end
	local onGoingRescueTargets = GetInstantProperty(owner, 'OnGoingRescueTargets') or {};
	if onGoingRescueTargets[GetObjKey(eventArg.Unit)] then
		-- 이미 다른놈이 출동함
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	local target = eventArg.Unit;
	if GetBuff(target, mastery.Buff.name) then
		return;
	end
	local myPos = GetPosition(owner);
	local targetPos = GetPosition(target);
	local applyDist = mastery.ApplyAmount;
	-- 향상된 긴급 구조 프로그램
	local mastery_Module_EmergencyRescueEnhanced = GetMasteryMastered(GetMastery(owner), 'Module_EmergencyRescueEnhanced');
	if mastery_Module_EmergencyRescueEnhanced then
		applyDist = applyDist + mastery_Module_EmergencyRescueEnhanced.ApplyAmount2;
	end
	if GetDistance3D(myPos, targetPos) >= (applyDist + 0.4) then
		return;
	end
	local limit = mastery.ApplyAmount2;
	-- 향상된 긴급 구조 프로그램
	if mastery_Module_EmergencyRescueEnhanced then
		limit = limit + mastery_Module_EmergencyRescueEnhanced.ApplyAmount;
	end
	if mastery.DuplicateApplyChecker >= limit then
		return;
	end
	if target.Race.name == 'Machine' or target.Race.name == 'Object' then
		return;
	end
	if owner.Cost < mastery.ApplyAmount3 then
		return;
	end
	
	local movePos = GetMovePosition(owner, targetPos, 1.8, true, nil, true);
	if not IsSamePosition(myPos, movePos) and not owner.Movable then
		-- 이동불가. 발동 안함.
		return;
	end
	local mission = GetMission(owner);
	if not IsValidPosition(mission, movePos) or GetDistance3D(movePos, targetPos) > 1.8 then
		return;
	end
	
	SetInstantProperty(owner, 'EmergencyRescueTarget', target);
	ds:WorldAction(Result_FireWorldEvent('EmergencyRescueReceived', {Receptionist = owner, Target = target}), true);
	StashCurrentActionChunk(mission);
	
	local objKey = GetObjKey(owner);
	local targetKey = GetObjKey(target);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Move(objKey, movePos);
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return Result_DirectingScript(function (mid, ds, args)
		if IsDead(owner) or mastery.CountChecker > 0 then
			mastery.CountChecker = 0;
			PopLastActionChunk(mid);
			return;
		end
		SetInstantProperty(owner, 'EmergencyRescueTarget', nil);
		ds:LookAt(objKey, targetKey);
		ds:Sleep(1.5);
		local resurrectID = ds:Resurrect(targetKey);
		local particleID = ds:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
		ds:Connect(resurrectID, particleID, 3.8);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
		
		local restoreAmount = mastery.ApplyAmount4;	
		local hpUpdate = Result_PropertyUpdated('HP', math.floor(target.MaxHP * restoreAmount / 100), target, true);
		hpUpdate.sequential = true;
		
		local actions = {};
		table.insert(actions, Result_Resurrect(target, 'Normal', true, mastery));
		table.insert(actions, Result_AddBuff(owner, target, mastery.Buff.name, 1));
		table.insert(actions, hpUpdate);
		table.insert(actions, Result_PropertyUpdated('Act', -target.Speed, target, nil, true));
		if not target.TurnState.TurnEnded then
			table.append(actions, {GetInitializeTurnActions(target)});
		end
		if owner.Info.name == 'Drone_Sprinkler' then
			InsertBuffActions(actions, owner, target, mastery.SubBuff.name, 1, true);
		end
		AddActionCostForDS(actions, owner, -mastery.ApplyAmount3, true, nil, ds);
		table.insert(actions, Result_FireWorldEvent('EmergencyRescueCompleted', {Receptionist = owner, Target = target, Succeed = true}));
		--table.insert(actions, Result_FireWorldEvent('UnitReturnFromDeath', {Unit = target}));
		table.insert(actions, Result_DirectingScript(function(mid, ds, args)
			PopLastActionChunk(mid);
		end, nil));
		return unpack(actions);
	end, nil, true, true);
end
-- 특성 : 전우애
function Mastery_Comradeship_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner
		or GetRelation(owner, eventArg.Unit) ~= 'Team'
		or eventArg.Unit.Obstacle then
		return;
	end
	if not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end	
	-- 어빌리티 데미지인 경우에만 DuplicateApplyChecker를 사용한다.
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability' then
		if mastery.DuplicateApplyChecker > 0 then
			return;
		end
		mastery.DuplicateApplyChecker = 1;
	end
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	
	local actions = {};
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	elseif owner.Act > mastery.ApplyAmount then
		AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount, ds, 'Friendly');
	else
		table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	end
	return unpack(actions);
end
function Mastery_Catharsis_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
-- 특성 구사일생.
function Mastery_CheatDeath_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or GetBuff(owner, mastery.Buff.name) then
		return;
	end
	local applyAmount = mastery.ApplyAmount;
	-- 빗나간 죽음
	local mastery_LuckyCheatDeath = GetMasteryMastered(GetMastery(owner), 'LuckyCheatDeath');
	if mastery_LuckyCheatDeath then
		local adjustValue = GetInstantProperty(owner, mastery_LuckyCheatDeath.name) or 0;
		applyAmount = applyAmount + adjustValue;
	end
	if RandomTest(100 - applyAmount) then
		return;
	end
	
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', true);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Sleep(1.5);
	local resurrectID = ds:Resurrect(objKey);
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/CheatDeath', 2);
	ds:Connect(particleID, resurrectID, 0);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	local hpUpdate = Result_PropertyUpdated('HP', owner.MaxHP, owner, true);
	hpUpdate.sequential = true;
	
	local actions = {};
	table.insert(actions, Result_Resurrect(owner, 'Normal', true, mastery));
	table.insert(actions, Result_AddBuff(owner, owner, mastery.Buff.name, 1));
	table.insert(actions, hpUpdate);
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	-- 빗나간 죽음
	if mastery_LuckyCheatDeath then
		SetInstantProperty(owner, mastery_LuckyCheatDeath.name, nil);
	end
	return unpack(actions);
end
-- 특성 불살
function Mastery_DoNotKill_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner or eventArg.Unit == owner then
		return;
	end
	local buff = GetBuff(owner, mastery.Buff.name );
	if not buff then
		return;
	end	
	local actions = {};	
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, -1 * buff.Lv);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	return unpack(actions);
end

-- 특성 : 겨울잠
function Mastery_Hibernation_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or GetBuff(owner, 'Rebirth') then
		return;
	end
	
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', true);
	ds:Sleep(0.5);
	ds:Resurrect(objKey);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	local hpUpdate = Result_PropertyUpdated('HP', 1, owner, true);
	hpUpdate.sequential = true;
	return Result_Resurrect(owner, 'Normal', true, mastery), Result_AddBuff(owner, owner, 'Rebirth', 1), Result_AddBuff(owner, owner, mastery.Buff.name, 1, nil,true), hpUpdate;
end
-- 특성 원령
function Mastery_VindictiveSpirit_UnitDead(eventArg, mastery, owner, ds)
	local killer = eventArg.Killer;
	if killer == nil or killer == owner then
		return;
	end
	local actions = {};
	local targetKey = GetObjKey(killer);
	local ownerKey = GetObjKey(owner);
	
	local cam = ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false);
	local f = ds:ForceEffect(ownerKey, '_CENTER_', targetKey, '_CENTER_', 'VindictiveSpirit');	
	local buffTurn = mastery.Buff.Turn;
	-- 분노의 마녀
	local mastery_WitchOfAnger = GetMasteryMastered(GetMastery(owner), 'WitchOfAnger');
	if mastery_WitchOfAnger then
		buffTurn = buffTurn + mastery_WitchOfAnger.ApplyAmount;
	end	
	InsertBuffActionsModifier(actions, owner, killer, mastery.Buff.name, 1, buffTurn);
	for _, action in ipairs(actions) do
		action._ref = f;
		action._ref_offset = -1;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead_Self', true);
	return unpack(actions);
end
-- 특성 희생
function Mastery_Sacrifice_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local targetList = {};
	local mission = GetMission(owner);
	local range = CalculateRange(owner, mastery.Range, GetPosition(owner));
	for i, pos in ipairs(range) do
		local target = GetObjectByPosition(mission, pos);
		if target and owner ~= target and GetRelation(owner, target) == 'Team' then
			table.insert(targetList, target);
		end
	end
	if #targetList == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead_Self', true);	
	local applyAct = -1 * mastery.ApplyAmount2;
	local buffTurn = mastery.Buff.Turn;
	-- 분노의 마녀
	local mastery_WitchOfAnger = GetMasteryMastered(GetMastery(owner), 'WitchOfAnger');
	if mastery_WitchOfAnger then
		buffTurn = buffTurn + mastery_WitchOfAnger.ApplyAmount4;
	end	
	for _, target in ipairs(targetList) do
		local targetKey = GetObjKey(target);
		local added, reasons = AddActionApplyAct(actions, owner, target, applyAct, 'Friendly');
		if added then
			ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(target, ds, reasons);
		InsertBuffActionsModifier(actions, owner, target, mastery.Buff.name, 1, buffTurn);	
	end
	return unpack(actions);
end
-- 이타주의자
function Mastery_Altruist_UnitDead_Self(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local targetList = {};
	local mission = GetMission(owner);
	local range = CalculateRange(owner, mastery.Range, GetPosition(owner));
	for i, pos in ipairs(range) do
		local target = GetObjectByPosition(mission, pos);
		if target and owner ~= target and GetRelation(owner, target) == 'Team' then
			table.insert(targetList, target);
		end
	end
	if #targetList == 0 then
		return;
	end
	local actions = {};
	local applyAct = -1 * mastery.ApplyAmount2;
	for _, target in ipairs(targetList) do
		local addSp = target.MaxSP - target.SP;
		AddSPPropertyActionsObject(actions, target, addSp, true, ds, true);
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead_Self', true);
	return unpack(actions);
end
-- 특성 지옥문
function Mastery_HellGate_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local killer = eventArg.Killer;
	
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local mission = GetMission(owner);
	local targetList = GetTargetInRangeSight(owner, mastery.Range, 'Enemy', true);
	
	local firstForce = nil;
	local cam = ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	for index, target in ipairs (targetList) do
		if target ~= killer then
			local targetKey = GetObjKey(target);
			local f = ds:ForceEffect(objKey, '_CENTER_', targetKey, '_CENTER_', 'VindictiveSpirit');
			InsertBuffActions(actions, owner, target, mastery.Buff.name, 1);
			actions[#actions]._ref = f;
			actions[#actions]._ref_offset = -1;
			if firstForce then
				ds:Connect(f, firstForce, 0);
			else
				firstForce = f;
			end
		end
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead_Self', true);
	return unpack(actions);
end
-- 특성 성난 황소
function Mastery_AngryBull_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or GetRelation(owner, eventArg.Unit) ~= 'Team'
		or owner.Affiliation.name ~= eventArg.Unit.Affiliation.name
		or eventArg.Unit.Obstacle then
		return;
	end
	local actions = {};	
	local pos = GetPosition(eventArg.Unit);
	if not IsInSight(owner, pos, true) then
		return;
	end
	local masteryBuff = GetBuff(owner, mastery.Buff.name);
	if masteryBuff and masteryBuff.Life == masteryBuff.Turn then
		return;
	end
	local objKey = GetObjKey(owner);
	local connectID = nil;
	if not masteryBuff and not GetBuffStatus(owner, 'Unconscious', 'Or') then
		local aniID = ds:PlayAni(objKey, 'Rage', false, -1, true);
		connectID = aniID;
	end
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if connectID == nil then
		connectID = masteryEventID;
	else
		ds:Connect(masteryEventID, connectID, 0);
	end
	ds:SetCommandLayer(connectID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(connectID);
	local chatID = ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	ds:Connect(chatID, masteryEventID, 0);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 특성 백호
function IsAllyRelation(from, to)
	local relation = GetRelation(from, to);
	return relation == 'Team' or relation == 'Ally';
end
function Mastery_WhiteTiger_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer == owner 
		or not IsAllyRelation(owner, eventArg.Killer)
		or owner.Affiliation.name ~= eventArg.Killer.Affiliation.name
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.Unit.Obstacle then
		return;
	end
	local actions = {};
	local pos = GetPosition(eventArg.Killer);
	if not IsInSight(owner, pos, true) then
		return;
	end
	local masteryBuff = GetBuff(owner, mastery.Buff.name);
	if masteryBuff and masteryBuff.Life == masteryBuff.Turn then
		return;
	end
	local objKey = GetObjKey(owner);
	local connectID = nil;
	if not masteryBuff and not GetBuffStatus(owner, 'Unconscious', 'Or') then
		local aniID = ds:PlayAni(objKey, 'Rage', false, -1, true);
		connectID = aniID;
	end
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if connectID == nil then
		connectID = masteryEventID;
	else
		ds:Connect(masteryEventID, connectID, 0);
	end
	ds:SetCommandLayer(connectID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(connectID);
	local chatID = ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	ds:Connect(chatID, masteryEventID, 0);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 특성 타오르는 불꽃
function Mastery_BurningFlame_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner then
		return;
	end
	if not IsEnemy(owner, eventArg.Unit) then
		return;
	end
	local actions = {};
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Fire', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	return unpack(actions);
end
-- 일반
function Mastery_NormalObject_UnitDead(eventArg, mastery, owner, ds)	
	local actions = {};
	
	local moveCam = ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	local lookPos = GetPosition(owner);
	local enableId = ds:EnableIf('TestPositionIsVisible', lookPos);
	ds:Connect(enableId, moveCam, -1);
	ds:SetCommandLayer(enableId, game.DirectingCommand.CM_SECONDARY);
	local delay = ds:Sleep(1.5);
	ds:SetCommandLayer(delay, game.DirectingCommand.CM_SECONDARY);
	ds:Connect(delay, enableId, 0);
	local destroyedMonType = GetInstantProperty(owner, 'DestroyedMonsterType');
	if destroyedMonType then
		local direction = GetDirection(owner);
		local clearDying = Result_ClearDyingObjects();
		clearDying._ref = delay;
		clearDying._ref_offset = 0;
		table.insert(actions, clearDying);
		local destroy = Result_CreateMonster(GenerateUnnamedObjKey(GetMission(owner)), destroyedMonType, GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		destroy._ref = delay;
		destroy._ref_offset = 0;
		table.insert(actions, destroy);
	end
	return unpack(actions);
end
-- 인화성
function Mastery_FlammableObject_UnitDead(eventArg, mastery, owner, ds)
	local flameExplosionInitializer = function(sprayObject, args)
		SetInstantProperty(sprayObject, 'MonsterType', 'Explosion');
		if eventArg.Killer then
			SetExpTaker(sprayObject,GetExpTaker(eventArg.Killer));
		end
		UNIT_INITIALIZER(sprayObject, sprayObject.Team, {Patrol = false});
	end;
	
	local usingPos = GetPosition(owner);
	local useAbilityName = owner.Ability[1].name;

	local explosionObjKey = GenerateUnnamedObjKey(GetMission(owner));
	local createAction = Result_CreateMonster(explosionObjKey, 'Explosion', usingPos, '_neutral_',  flameExplosionInitializer, {}, 'DoNothingAI', nil, true);
	local mission = GetMission(owner);
	ApplyActions(mission, { createAction }, false);
	local explosionObj = GetUnit(mission, explosionObjKey);
	-- 터지는 오브젝트의 MaxHP 비례 데미지 때문에, 생성된 오브젝트의 Base_MaxHP를 원본 오브젝트의 MaxHP로 덮어씀
	explosionObj.Base_MaxHP = owner.MaxHP;
	InvalidateObject(explosionObj);
	local abilityUse = Result_UseAbility(explosionObj, useAbilityName, usingPos, nil, true);
	abilityUse.sequential = true;
	
	local actions = {};
	table.insert(actions, Result_AddBuff(owner, owner, 'Burning', 1, nil, true, false, true));
	table.insert(actions, abilityUse);
	
	local destroyedMonType = GetInstantProperty(owner, 'DestroyedMonsterType');
	if destroyedMonType then
		local direction = GetDirection(owner);
		local destroy = Result_CreateMonster(GenerateUnnamedObjKey(GetMission(owner)), destroyedMonType, GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		destroy.sequential = true;
		local clearDying = Result_ClearDyingObject(owner);
		clearDying.sequential = true;
		table.insert(actions, destroy);
		table.insert(actions, clearDying);
	end
	return unpack(actions);
end
function Mastery_Obstacle_UnitDead(eventArg, mastery, owner, ds)
	local mission = GetMission(owner);
	local obstacleCls = GetClassList('Obstacle')[GetInstantProperty(owner, 'ObstacleType')];
	if obstacleCls.DestroyReward <= 0 then
		return;
	end
	mission.Instance.IllegalObjectReward = mission.Instance.IllegalObjectReward + obstacleCls.DestroyReward;
	mission.Instance.Obstacle[obstacleCls.name].DestroyCount = mission.Instance.Obstacle[obstacleCls.name].DestroyCount + 1;
end
-- 드라키 알
function Mastery_HatchedObject_UnitDead(eventArg, mastery, owner, ds)
	if owner.HP > 0 then
		return;
	end
	local actions = {};
	
	local particleId = ds:PlayParticle(GetObjKey(owner), '_BOTTOM_', 'Particles/Dandylion/Explosion_Egg', 2, false, false, true);
	local moveCam = ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	local lookPos = GetPosition(owner);
	local enableId = ds:EnableIf('TestPositionIsVisible', lookPos);
	ds:Connect(moveCam, enableId, -1);
	ds:SetCommandLayer(enableId, game.DirectingCommand.CM_SECONDARY);
	local delay = ds:Sleep(0);
	ds:SetCommandLayer(delay, game.DirectingCommand.CM_SECONDARY);
	ds:Connect(delay, enableId, 0);
	ds:Connect(particleId, enableId, 0);
	local destroyedMonType = GetInstantProperty(owner, 'DestroyedMonsterType');
	if destroyedMonType then
		local direction = GetDirection(owner);
		local clearDying = Result_ClearDyingObjects();
		clearDying._ref = delay;
		clearDying._ref_offset = 0;
		table.insert(actions, clearDying);
		local destroy = Result_CreateMonster(GenerateUnnamedObjKey(GetMission(owner)), destroyedMonType, GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		destroy._ref = delay;
		destroy._ref_offset = 0;
		table.insert(actions, destroy);
	end
	return unpack(actions);
end
function Mastery_Deathblow_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.TargetInfo ==nil
		or not eventArg.TargetInfo.IsDead
		or eventArg.TargetInfo.PrevHP ~= eventArg.TargetInfo.MaxHP then
		return;
	end
	
	mastery.DuplicateApplyChecker = 1;
	
	ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name });
	local actions = {};
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	return unpack(actions);
end
-- 피범벅
function Mastery_Bloodbath_UnitKilled(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or not IsEnemy(owner, eventArg.Unit)
		or not HasBuffType(eventArg.Unit, nil, nil, mastery.BuffGroup.name, true)
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	if owner.TurnState.TurnEnded then
		local added, reasons = AddActionApplyAct(actions, owner, owner, -1 * mastery.ApplyAmount, 'Friendly');
		if added then
			ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = -1 * mastery.ApplyAmount, Delay = true });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	else
		AddActionRestoreFullActions(actions, owner);
	end
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_Bloodbath_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
function Mastery_Rampage_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.TargetInfo == nil
		or not eventArg.TargetInfo.IsDead then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = -mastery.ApplyAmount });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_Rampage_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
function Mastery_BloodWind_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or eventArg.DamageInfo == nil
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.TargetInfo == nil
		or not eventArg.TargetInfo.IsDead then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = -mastery.ApplyAmount });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	AddSPPropertyActions(actions, owner, 'Wind', mastery.ApplyAmount2, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_BloodWind_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
-- 특성 승리의 포효
function Mastery_VictoryShout_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or eventArg.DamageInfo == nil
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.TargetInfo == nil
		or not eventArg.TargetInfo.IsDead then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead', true);
	local addSP = mastery.ApplyAmount;
	-- 분노의 외침
	local mastery_BarbarianShout = GetMasteryMastered(GetMastery(owner), 'BarbarianShout');
	if mastery_BarbarianShout then
		MasteryActivatedHelper(ds, mastery_BarbarianShout, owner, 'UnitDead');
		addSP = addSP + mastery_BarbarianShout.ApplyAmount;
	end
	AddSPPropertyActionsObject(actions, owner, addSP, true, ds, true);
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_VictoryShout_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
-- 특성 광견.
function Mastery_CrazyDog_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or eventArg.DamageInfo == nil
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.TargetInfo == nil
		or not eventArg.TargetInfo.IsDead then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	AddSPPropertyActions(actions, owner, owner.ESP.name, mastery.ApplyAmount, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_CrazyDog_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
-- 영혼 인도자
function Mastery_SoulGuide_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or eventArg.Unit.Obstacle 
		or not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end
	-- 생명체가 아니면 리턴.
	local target = eventArg.Unit;
	if not target.Race.Life then
		return;
	end
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
end
-- 사령술사 팔찌
function Mastery_Bangle_EtrosPriest_Legend_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or eventArg.Unit.Obstacle 
		or not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end
	-- 생명체가 아니면 리턴.
	local target = eventArg.Unit;
	if not target.Race.Life then
		return;
	end
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + mastery.ApplyAmount2;
end
function Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, explodeAbility, directingConfig, team)
	local flameExplosionInitializer = function(sprayObject, args)
		SetInstantProperty(sprayObject, 'MonsterType', 'Explosion');
		SetInstantProperty(sprayObject, 'NoTeamUnitCounter', true);
		if eventArg.Killer then
			SetExpTaker(sprayObject,GetExpTaker(eventArg.Killer));
		end
		UNIT_INITIALIZER(sprayObject, sprayObject.Team, {Patrol = false});
	end;
	
	local usingPos = GetPosition(owner);
	local useAbilityName = explodeAbility;

	local explosionObjKey = GenerateUnnamedObjKey(GetMission(owner));
	local createAction = Result_CreateMonster(explosionObjKey, 'Explosion', usingPos, team or '_neutral_',  flameExplosionInitializer, {}, 'DoNothingAI', nil, true);
	local mission = GetMission(owner);
	ApplyActions(mission, { createAction }, false);
	local explosionObj = GetUnit(mission, explosionObjKey);
	-- 데미지 공식의 Lv 때문에 원본 오브젝트의 Lv 반영
	explosionObj.Lv = owner.Lv;
	-- 터지는 오브젝트의 MaxHP 비례 데미지 때문에, 생성된 오브젝트의 Base_MaxHP를 원본 오브젝트의 MaxHP로 덮어씀
	explosionObj.Base_MaxHP = owner.MaxHP;
	-- 연료 폭발
	local mastery_Module_SuicideWithFuel = GetMasteryMastered(GetMastery(owner), 'Module_SuicideWithFuel');
	if mastery_Module_SuicideWithFuel then
		-- Cost 비례 데미지
		local explosionAbility = GetAbilityObject(explosionObj, useAbilityName);
		if explosionAbility then
			SafeNewIndex(explosionAbility.AdditionalApplyAmount, 'Cost', 100);
			explosionObj.Cost = owner.Cost;
		end
	end
	InvalidateObject(explosionObj);
	local abilityUse = Result_UseAbility(explosionObj, useAbilityName, usingPos, nil, true, directingConfig or {});
	abilityUse.sequential = true;
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead_Self', false);
	
	return abilityUse, Result_DestroyObject(explosionObj, false, true);
end
-- 얼음주머니
function Mastery_IceSac_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, mastery.ChainAbility);
end
-- 번개주머니
function Mastery_LightningSac_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, mastery.ChainAbility);
end
-- 독주머니
function Mastery_VenomSac_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, mastery.ChainAbility);
end
-- 불꽃주머니
function Mastery_FlameSac_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, mastery.ChainAbility);
end
-- 거미줄 주머니
function Mastery_WebSac_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, 'ToxicLeakage_WebSac', nil, GetTeam(owner));
end
-- 연료 폭발
function Mastery_Module_SuicideWithFuel_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, mastery.ChainAbility);
end
-- 티마
function Mastery_Tima_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner or not IsEnemy(owner, eventArg.Unit) then
		return;
	end
	if not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end	
	-- 어빌리티 데미지인 경우에만 DuplicateApplyChecker를 사용한다.
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability' then
		if mastery.DuplicateApplyChecker > 0 then
			return;
		end
		mastery.DuplicateApplyChecker = 1;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	-- 코스트
	local addCost = mastery.ApplyAmount;
	local _, reasons = AddActionCost(actions, owner, addCost, true);			
	ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost });
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	return unpack(actions);
end
-- 동질감
function Mastery_SenseOfKinship_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer == owner 
		or not IsAllyRelation(owner, eventArg.Killer)
		or not IsEnemy(owner, eventArg.Unit)
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local pos = GetPosition(eventArg.Killer);
	if not IsInSight(owner, pos, true) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 거짓 정보
function Mastery_FakeInformation_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer == owner then
		return;
	end
	local actions = {};
	local target = eventArg.Killer;
	local targetKey = GetObjKey(target);
	local applyAct = mastery.ApplyAmount;
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	local added, reasons = AddActionApplyAct(actions, owner, target, applyAct, 'Hostile');
	if added then
		ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(target, ds, reasons);
	return unpack(actions);
end
-- 생존 모드
function Mastery_Module_SurvivalMode_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner then
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	local target = eventArg.Unit;
	if SafeIndex(target, 'Race', 'name') ~= 'Machine' then
		return;
	end
	local targetPos = GetPosition(target);
	if not IsInSight(owner, targetPos, true) then
		return;
	end
	-- 체력 충분
	if owner.HP / owner.MaxHP > mastery.ApplyAmount / 100 then
		return;
	end
	-- 연료 부족 or 이동 불가
	if owner.Cost < mastery.ApplyAmount4 or not owner.Movable then
		return;
	end
	local movePos = GetMovePosition(owner, targetPos, 1.8, true, nil, true);
	local mission = GetMission(owner);
	if not IsValidPosition(mission, movePos) or GetDistance3D(movePos, targetPos) > 1.8 then
		return;
	end
	local objKey = GetObjKey(owner);
	local targetKey = GetObjKey(target);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Move(objKey, movePos);
	ds:LookAt(objKey, targetKey);
	ds:Sleep(1.5);
	ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');	
	-- 비용 소모
	AddActionApplyActForDS(actions, owner, owner, mastery.ApplyAmount3, ds, 'Cost');
	local resultCost = AddActionCostForDS(actions, owner, -mastery.ApplyAmount4, true, nil, ds);
	owner.Cost = resultCost;
	-- 연료 회복
	if target.Cost > 0 then
		AddActionCostForDS(actions, owner, target.Cost, true, nil, ds);		
	end
	-- 체력 회복
	local addHP = target.MaxHP * mastery.ApplyAmount2/100;
	local reasons = {};
	addHP, reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false); 
	-- 자율 행동 강화 프로그램
	local mastery_Module_AutoAction = GetMasteryMastered(GetMastery(owner), 'Module_AutoAction');
	if mastery_Module_AutoAction then
		AddActionApplyActForDS(actions, owner, owner, -mastery_Module_AutoAction.ApplyAmount2, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_Module_AutoAction, owner, 'UnitDead');
	end	
	-- 향상된 생존 모드
	local mastery_Module_EnhancedSurvivalMode = GetMasteryMastered(GetMastery(owner), 'Module_EnhancedSurvivalMode');
	if mastery_Module_EnhancedSurvivalMode and owner.MaxHP ~= owner.HP and owner.HP + addHP >= owner.MaxHP then
		MasteryActivatedHelper(ds, mastery_Module_EnhancedSurvivalMode, owner, 'UnitDead');
		if owner.TurnState.TurnEnded then
			table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
		else
			table.append(actions, {GetInitializeTurnActions(owner)});
		end
	end
	return unpack(actions);
end
-- 나는 히어로 아이린이다!
function Mastery_ImHeroIrene_UnitDead(eventArg, mastery, owner, ds)
	if owner == eventArg.Unit
		or not IsTeamOrAlly(owner, eventArg.Unit)
		or not IsInSight(owner, GetPosition(eventArg.Unit), true)
		or eventArg.Unit.Obstacle then
		return;
	end
	-- 어빌리티 데미지인 경우에만 DuplicateApplyChecker를 사용한다.
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability' then
		-- 히어로의 책임감 특성으로 버프가 걸렸을 수 있으므로, PreAbilityUsing에서 미리 확인한 버프 유무를 사용함
		local hasBuff = GetInstantProperty(owner, mastery.name);
		if not hasBuff or mastery.DuplicateApplyChecker > 0 then
			return;
		end
		mastery.DuplicateApplyChecker = 1;
	else
		-- 버프 체크
		if not HasBuff(owner, mastery.SubBuff.name) then
			return;
		end	
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	if owner.TurnState.TurnEnded then
		table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	else
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 광기의 심장
function Mastery_MadnessHeart_UnitDead(eventArg, mastery, owner, ds)
	if GetBuff(owner, mastery.Buff.name) then
		return;
	end
	if not HasBuffType(owner, nil, nil, mastery.BuffGroup.name, true) then
		return;
	end
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Sleep(1.5);
	local restoreAmount = mastery.ApplyAmount;
	local resurrectID = ds:Resurrect(objKey);
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
	ds:Connect(resurrectID, particleID, 3.8);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});	
	local hpUpdate = Result_PropertyUpdated('HP', math.max(1, math.floor(owner.MaxHP * restoreAmount / 100)), owner, true);
	hpUpdate.sequential = true;
	
	local actions = {};
	table.insert(actions, Result_Resurrect(owner, 'Normal', true, mastery));
	table.insert(actions, Result_AddBuff(owner, owner, mastery.Buff.name, 1));
	table.insert(actions, hpUpdate);
	-- 불멸자
	local mastery_MadnessImmortal = GetMasteryMastered(GetMastery(owner), 'MadnessImmortal');
	if mastery_MadnessImmortal then
		MasteryActivatedHelper(ds, mastery_MadnessImmortal, owner, 'UnitDead');
		InsertBuffActionsModifier(actions, owner, owner, mastery_MadnessImmortal.Buff.name, 1, mastery_MadnessImmortal.ApplyAmount, true);
	end	
	return unpack(actions);
end
-- 굳건한 결의
function Mastery_StrongWill_UnitDead(eventArg, mastery, owner, ds)
	if not IsDead(owner) then
		return;
	end
	if mastery.DuplicateApplyChecker >= mastery.ApplyAmount then
		return;
	end
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Sleep(1.5);
	local resurrectID = ds:Resurrect(objKey);
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
	ds:Connect(resurrectID, particleID, 3.8);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	
	local hpUpdate = Result_PropertyUpdated('HP', owner.MaxHP, owner, true);
	hpUpdate.sequential = true;
	
	local actions = {};
	table.insert(actions, Result_Resurrect(owner, 'Normal', true, mastery));
	table.insert(actions, hpUpdate);
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	return unpack(actions);
end
-- 살금 살금/슬금 슬금
function Mastery_StealthyFootsteps_UnitDead(eventArg, mastery, owner, ds)
	-- 이동 중에 사망 시에는 UnitMoved가 불리지 않으므로, 부활 시를 대비해서 UnitDead에서 바로 비활성화함
	mastery.CountChecker = 0;
	mastery.DuplicateApplyChecker = 0;
end
-- 닌자 구급함
function Mastery_NinjaHealToolkit_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or GetRelation(owner, eventArg.Unit) ~= 'Team'
		or eventArg.Unit.Obstacle then
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	local target = eventArg.Unit;
	if GetBuff(target, mastery.Buff.name) then
		return;
	end
	local myPos = GetPosition(owner);
	local targetPos = GetPosition(target);
	local applyDist = 1;
	if GetDistance3D(myPos, targetPos) >= (applyDist + 0.4) then
		return;
	end
	if target.Race.name == 'Machine' or target.Race.name == 'Object' then
		return;
	end
	local objKey = GetObjKey(owner);
	local targetKey = GetObjKey(target);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:LookAt(objKey, targetKey);
	ds:Sleep(1.5);
	local resurrectID = ds:Resurrect(targetKey);
	local particleID = ds:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
	ds:Connect(resurrectID, particleID, 3.8);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	
	local restoreAmount = mastery.ApplyAmount2;	
	local hpUpdate = Result_PropertyUpdated('HP', math.floor(target.MaxHP * restoreAmount / 100), target, true);
	hpUpdate.sequential = true;
	
	local actions = {};
	table.insert(actions, Result_Resurrect(target, 'Normal', true, mastery));
	table.insert(actions, Result_AddBuff(owner, target, mastery.Buff.name, 1));
	table.insert(actions, hpUpdate);
	return unpack(actions);
end
-- 부활의 물약
function GetHealPotionAbilityList(target)
	local ret = {};
	local equipmentList = GetClassList('Equipment');
	for equipPos, _ in pairs(equipmentList) do
		local item = target[equipPos];
		if item and item.name and item.Consumable then
			local ability = item.Ability;
			if ability.name ~= nil and ability.Type == 'Heal' and ability.SubType2 == 'HP' and ability.IsUseCount and ability.UseCount > 0 then
				table.insert(ret, ability);
			end
		end
	end
	return ret;
end
function Mastery_RebirthPotion_UnitDead(eventArg, mastery, owner, ds)
	if GetBuff(owner, mastery.Buff.name) then
		return;
	end
	local healPotionAbilityList = GetHealPotionAbilityList(owner);
	if #healPotionAbilityList == 0 then
		return;
	end
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Sleep(1.5);
	local resurrectID = ds:Resurrect(objKey);
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
	ds:Connect(resurrectID, particleID, 3.8);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	-- 회복량 계산
	local restoreAmount = 0;
	local mission = GetMission(owner);
	local weather = mission.Weather.name;
	local temperature = mission.Temperature.name;
	for _, ability in ipairs(healPotionAbilityList) do
		local healAmount = GetDamageCalculator(owner, owner, ability, weather, temperature, GetPosition(owner), 1, nil, nil, nil, nil, {});
		restoreAmount = restoreAmount + healAmount * ability.UseCount;
	end
	if restoreAmount > owner.MaxHP then
		restoreAmount = owner.MaxHP;
	end
	local hpUpdate = Result_PropertyUpdated('HP', restoreAmount, owner, true);
	hpUpdate.sequential = true;
	local actions = {};
	-- 정제된 부활의 물약
	local mastery_EnhancedRebirthPotion = GetMasteryMastered(GetMastery(owner), 'EnhancedRebirthPotion');
	if mastery_EnhancedRebirthPotion then
		resetSP = false;
	end
	table.insert(actions, Result_Resurrect(owner, 'Normal', resetSP, mastery));
	table.insert(actions, Result_AddBuff(owner, owner, mastery.Buff.name, 1));
	table.insert(actions, hpUpdate);
	-- 아이템 소모
	for _, ability in ipairs(healPotionAbilityList) do
		UpdateAbilityPropertyActions(actions, owner, ability.name, 'UseCount', 0);
	end
	if restoreAmount == owner.MaxHP then
		-- 턴 획득
		table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
		if not owner.TurnState.TurnEnded then
			table.append(actions, {GetInitializeTurnActions(owner)});
		end
	end
	-- 정제된 부활의 물약
	if mastery_EnhancedRebirthPotion then
		MasteryActivatedHelper(ds, mastery_EnhancedRebirthPotion, owner, 'UnitDead_Self');
		AddOverchargeActionsObject(actions, owner, ds);
		InsertBuffActions(actions, owner, owner, mastery_EnhancedRebirthPotion.Buff.name, 1, true);
	end	
	return unpack(actions);
end
-- 폭주
function Mastery_Module_MachineFury_UnitDead(eventArg, mastery, owner, ds)
	-- 연타 공격으로 어중간한 상태로 죽었으면 상태 리셋
	if mastery.DuplicateApplyChecker ~= 1 then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
-----------------------------------------------------------------------
-- 유닛 부활. [UnitResurrect]
-------------------------------------------------------------------------------
-- 히어로는 포기하지 않는다.
function Mastery_HeroDontGiveUp_UnitResurrect(eventArg, mastery, owner, ds)
	MasteryActivatedHelper(ds, mastery, owner, 'UnitResurrect_Self');
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	
	local mastery_ImHeroIrene = GetMasteryMastered(GetMastery(owner), 'ImHeroIrene');
	if mastery_ImHeroIrene then
		local activate = false;
		Linq.new(GetAllUnitInSight(owner, true))
		:where(function(o) return owner ~= o and IsAllyOrTeam(owner, o); end)
		:foreach(function(o)
			InsertBuffActions(actions, owner, o, mastery_ImHeroIrene.Buff.name, 1, true);
			activate = true;
		end);
		if activate then
			MasteryActivatedHelper(ds, mastery_ImHeroIrene, owner, 'UnitResurrect_Self');
		end
		table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
		if not owner.TurnState.TurnEnded then
			table.append(actions, {GetInitializeTurnActions(owner)});
		end
	end
	return unpack(actions);
end
function Mastery_LastFlame_UnitResurrect(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};	
	local invoker = eventArg.ResurrectInfo.invoker;
	if invoker and invoker.name == 'Phoenix' then
		if owner.Overcharge > 0 then
			table.insert(actions, Result_PropertyUpdated('Overcharge', owner.OverchargeDuration, owner, false, true));
		else
			AddSPPropertyActions(actions, owner, owner.ESP.name, owner.MaxSP - owner.SP, true, ds, true);
		end
	end
	return unpack(actions);
end
-- 광전사
function Mastery_Berserker_UnitResurrect(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
-- 지식의 보고
function Mastery_TreasureHouseOfKnowledge_UnitResurrect(eventArg, mastery, owner, ds)
	local company = GetCompany(owner);
	if not company then
		return;
	end
	local prevTHOK = GetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount');
	SetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount', prevTHOK + mastery.ApplyAmount);
end
-- 보물지도
function Mastery_TreasureMap_UnitResurrect(eventArg, mastery, owner, ds)
	local company = GetCompany(owner);
	if not company then
		return;
	end
	local prevTHOK = GetCompanyInstantProperty(company, 'TreasureMapAmount');
	SetCompanyInstantProperty(company, 'TreasureMapAmount', prevTHOK + mastery.ApplyAmount);
end
-----------------------------------------------------------------------
-- 유닛 이동시작. [UnitMoveStarted]
-------------------------------------------------------------------------------
-- 이동중 블락 개시
function Mastery_UnitMovingBlocker_UnitMoveStarted(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 1;
end
-- 거미줄 잇기
function Mastery_JoinCobweb_UnitMoveStarted(eventArg, mastery, owner, ds)
	local fieldEffects = GetFieldEffectByPosition(owner, eventArg.BeginPosition);
	local enabled = false;
	for _, instance in ipairs(fieldEffects) do
		local type = instance.Owner.name;
		if type == 'Web' then
			enabled = true;
			break;
		end
	end
	
	if not enabled then
		return;
	end
	
	mastery.DuplicateApplyChecker = 1;
end
-- 거미줄 재단사
function Mastery_WebTailor_UnitMoveStarted(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 1;
end
-- 고속 호버링
function Mastery_Module_HighSpeedHovering_UnitMoveStarted(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or owner.TurnState.TurnEnded then
		return;
	end
	
	local satisfied = false;
	if eventArg.MovingForAbility then
		local totalPathLength = 0;
		local prevPos = eventArg.StraightPath[1];
		for i, pos in ipairs(eventArg.StraightPath) do
			totalPathLength = totalPathLength + GetDistance3D(prevPos, pos);
			prevPos = pos;
		end
		satisfied = totalPathLength > mastery.ApplyAmount;
	else
		satisfied = eventArg.IsDash;
	end
	if not satisfied then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
end
-- 살금 살금/슬금 슬금
function Mastery_StealthyFootsteps_UnitMoveStarted(eventArg, mastery, owner, ds)
	local totalPathLength = 0;
	local prevPos = eventArg.StraightPath[1];
	for i, pos in ipairs(eventArg.StraightPath) do
		totalPathLength = totalPathLength + GetDistance3D(prevPos, pos);
		prevPos = pos;
	end
	local satisfied = false;
	if totalPathLength <= owner.MoveDist * mastery.ApplyAmount / 100 then
		satisfied = true;
	end
	-- 잠행술의 대가, 수풀 속의 그림자
	local mastery_Stealthwalker = GetMasteryMasteredList(GetMastery(owner), {'Stealthwalker', 'BushStealthWalker'});
	if mastery_Stealthwalker and HasBuff(owner, mastery_Stealthwalker.Buff.name) then
		satisfied = true;
	end
	if satisfied then
		mastery.CountChecker = 1;
	else
		mastery.CountChecker = 0;
	end
	mastery.DuplicateApplyChecker = 0;
end
function Mastery_StealthyFootsteps_Invoked(eventArg, mastery, owner, ds, pos)
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
	local targetKey = GetObjKey(owner);
	local refID = -1;
	if pos then
		local eventCmd = ds:SubscribeFSMEvent(targetKey, 'StepForward', 'CheckUnitArrivePosition', {CheckPos=pos}, true, true);
		if eventArg and eventArg.MoveID and ds:GetRefID(eventArg.MoveID) ~= eventArg.MoveID then
			ds:Connect(eventCmd, eventArg.MoveID, 0);		-- 루프를 만들어서 교체를 시키려고
			ds:Connect(eventArg.MoveID, eventCmd, 0);
		else
			ds:SetConditional(eventCmd);
		end
		refID = eventCmd;
	end
	ds:Connect(ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery.name }), refID, 0);

	local actions = {};
	-- 대도
	local mastery_GreatThief = GetMasteryMastered(GetMastery(owner), 'GreatThief');
	if mastery_GreatThief then
		ds:Connect(ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery_GreatThief.name }), refID, 0);
		InsertBuffActions(actions, owner, owner, mastery_GreatThief.SubBuff.name, 1, true);
	end
	return unpack(actions);
end
-----------------------------------------------------------------------
-- 어빌리티 사용 임박 [PreAbilityUsing]
-----------------------------------------------------------------------
-- 나를 두려워 하라.
---@param eventArg preAbilityUsingEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_ThreatScattershot_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force'
		or not IsGetAbilitySubType(eventArg.Ability, 'Piercing')
	then
		return;
	end

	local targetPos = eventArg.PositionList[#(eventArg.PositionList)];
	local enemies = Linq.new(BuildApplyTargetInfos(owner, eventArg.Ability, targetPos))
		:select(function(info) return {info.Object} end)
		:where(function(d) return d[1] and IsEnemy(owner, d[1]) end)
		:select(function(d) return d[1] end)
		:toList();
	if #enemies < mastery.ApplyAmount then
		return;
	end

	mastery.DuplicateApplyChecker = 1;
end
-- 비틀린 쾌락
function Mastery_BrutalityTargetWeakMan_PreAbilityUsing(eventArg, mastery, owner, ds)
	local minHPTarget = Linq.new(GetAllUnitInSight(owner, true))
		:where(function(u) return u.HP < u.MaxHP and IsEnemy(owner, u) end)
		:orderByAscending(function(u) return u.HP; end)
		:first();
	if minHPTarget then
		mastery.RefPersonType = GetObjKey(minHPTarget);
	else
		mastery.RefPersonType = '';
	end
end
-- 수풀 매복
function Mastery_BushAmbushHunter_PreAbilityUsing(eventArg, mastery, owner, ds)
	SetInstantProperty(owner, 'BushAmbushHunter', GetInstantProperty(owner, 'AbilityPrevPosition') or GetPosition(owner));
	Mastery_BurrowHunter_PreAbilityUsing(eventArg, mastery, owner, ds);
end
-- 땅굴 속의 사냥꾼, 땅굴 함정
function Mastery_BurrowHunter_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = HasBuff(owner, mastery.Buff.name) and 1 or 0;
end
-- 준비된 사격
function Mastery_PreparationFire_PreAbilityUsing(eventArg, mastery, owner, ds)
	if not IsGetAbilitySubType(eventArg.Ability, 'Piercing')
		or not IsStableAttack(owner) then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
end
-- 엄호
function Mastery_Covering_PreAbilityUsing(eventArg, mastery, owner, ds)
	if 	eventArg.Unit == owner
		or mastery.CountChecker >= mastery.ApplyAmount
		or eventArg.Ability.Type ~= 'Attack' 
		or eventArg.Ability.RelocatorMoveType == 'Flash'
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or GetBuffStatus(owner, 'Unconscious', 'Or')
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or not IsInSight(owner, eventArg.Unit, true) then
		return;
	end
	local target = eventArg.Unit;
	local targetPos = GetPosition(target);
	local usingPos = eventArg.PositionList[1];
	local applyArea = CalculateRange(target, eventArg.Ability.ApplyRange, usingPos);
	
	local canHit, bf = HasBestFriendWithMastery(owner, mastery.name, function(bf)
		local bfPos = GetPosition(bf);
		return PositionInRange(applyArea, bfPos);
	end);
	if not canHit then
		return;
	end
	
	local resultModifier = {
		ReactionAbility = true
	};
	mastery.CountChecker = mastery.CountChecker + 1;
	local actions = {Mastery_TryAttackIfAvailable(owner, {[GetObjKey(eventArg.Unit)] = true}, resultModifier, {Result_DirectingScript(function(mid, ds, args)
		BestFriendMasteryActivatedHelper(ds, mastery, owner, 'PreAbilityUsing_Self');
		ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false, true, 0.75);
		return Result_FireWorldEvent('BestFriendMasteryActivated', {Unit = owner, Target = bf, Mastery = mastery.name}, nil, true);
	end)}, {Result_DirectingScript(function(mid, ds, args)
		mastery.CountChecker = mastery.CountChecker - 1;
	end)})};

	local action = actions[1];
	if action and action.type == 'UseAbility' and eventArg.DirectingConfig.Preemptive then
		local eventCmd = eventArg.RealActionID;
		action.directing_config.Preemptive = eventArg.DirectingConfig.Preemptive;
		action.directing_config.PreemptiveOrder = 0;
		action.nonsequential = true;
		action._overtake_ref = eventCmd;
		action._ref_offset = -1;
	end
	return unpack(actions);
end
-- 나는 포기하지 않는다
function Mastery_IDontGiveUp_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.CountChecker = 0;
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force' then
		return;
	end
	local targetPos = eventArg.PositionList[#(eventArg.PositionList)];
	local applyTargets = table.filter(BuildApplyTargetInfos(owner, eventArg.Ability, targetPos), function(info)
		return info.Object and IsEnemy(owner, info.Object);
	end);
	if #applyTargets < mastery.ApplyAmount then
		return;
	end
	mastery.CountChecker = 1;
	targetList = table.map(applyTargets, function(info) return GetObjKey(info.Object) end);
	SetInstantProperty(owner, 'IDontGiveUp_Target', targetList);
end
-- 반동 제어기
function Mastery_Module_ControlReactor_PreAbilityUsing(eventArg, mastery, owner, ds)
	if owner.TurnState.TurnEnded
		or eventArg.Ability.Type ~= 'Attack'
		or owner.TurnState.Moved then
		return;
	end
	local isOvercharge = owner.Overcharge > 0;	
	local usingAbility = eventArg.Ability;
	return Result_DirectingScript(function (mid, ds, args)
		local actions = {};
		MasteryActivatedHelper(ds, mastery, owner, 'PreAbilityUsing_Self');
		AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount, ds, 'Friendly', nil, nil, usingAbility);
		-- 최대 출력 공격
		local mastery_Module_OverchargeAttack = GetMasteryMastered(GetMastery(owner), 'Module_OverchargeAttack');
		if mastery_Module_OverchargeAttack and isOvercharge then
			MasteryActivatedHelper(ds, mastery_Module_OverchargeAttack, owner, 'PreAbilityUsing_Self');
			AddActionApplyActForDS(actions, owner, owner, -mastery_Module_OverchargeAttack.ApplyAmount, ds, 'Friendly', nil, nil, usingAbility);
		end
		-- 공격 전환 최적화
		local mastery_Module_EnhancedMeleeDefenceReaction = GetMasteryMastered(GetMastery(owner), 'Module_EnhancedMeleeDefenceReaction');
		if mastery_Module_EnhancedMeleeDefenceReaction then
			MasteryActivatedHelper(ds, mastery_Module_EnhancedMeleeDefenceReaction, owner, 'PreAbilityUsing_Self');
			AddAbilityCoolActions(actions, owner, -mastery_Module_EnhancedMeleeDefenceReaction.ApplyAmount, function(ability)
				return ability.name == usingAbility.name;
			end);
		end
		return unpack(actions);
	end, nil, true, true);
end
-- 그물 위의 사냥꾼, 수면 위의 사냥꾼, 수풀 속의 사냥꾼
function Mastery_OnFieldHunter_PreAbilityUsing(eventArg, mastery, owner, ds)
	if IsObjectOnFieldEffectBuffAffector(owner, { mastery.Buff.name, mastery.SubBuff.name }, true) then
		mastery.DuplicateApplyChecker = 1;
	else
		mastery.DuplicateApplyChecker = 0;
	end
end
-- 하늘 위의 사냥꾼
function Mastery_OntheSkyHunter_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local prevPos = GetAbilityUsingPosition(owner);
	SetInstantProperty(owner, 'OntheSkyHunter', prevPos);
end
-- 외로운 싸움꾼
function Mastery_LonelyFighter_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	
	-- 특성 외토리늑대. 6칸 안에 아군 유닛이 없으면 명중률이 상승
	local targetList = GetTargetInRangeSightReposition(SafeIndex(eventArg.Ability, 'AbilityWithMove'), owner, mastery.Range, 'Team', true);
	if #targetList > 0 then
		return;
	end
	
	local actions = {};
	local action, reasons = GetApplyActAction(owner, -mastery.ApplyAmount, nil, 'Friendly', owner, eventArg.Ability);
	if action then
		table.insert(actions, action);
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -mastery.ApplyAmount });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	
	return unpack(actions);
end
-- 기선 제압
function GetMeleeAbilityUseAction(user, target, resultModifier, directingConfig)
	local overwatchAbility = FindAbility(user, user.OverwatchAbility_Melee);
	if not overwatchAbility or overwatchAbility.HitRateType ~= 'Melee' or not IsAvailableAbility(user, overwatchAbility) then
		return false;
	end
	local userPos = GetPosition(user);
	local usingPos = GetPosition(target);
	if not IsMeleeDistance(userPos, usingPos) then
		return false;
	end
	local range = CalculateRange(user, overwatchAbility.TargetRange, userPos);
	local canHit = PositionInRange(range, usingPos);
	
	if not canHit then
		return false;
	end
	
	local abilityAction = Result_UseAbility(user, overwatchAbility.name, usingPos, resultModifier, true, directingConfig);
	abilityAction.free_action = true;
	abilityAction.final_useable_checker = function()
		return GetBuffStatus(user, 'Attackable', 'And')
			and PositionInRange(CalculateRange(user, overwatchAbility.TargetRange, GetPosition(user)), usingPos)
	end;
	return true, abilityAction;
end
function Mastery_Forestallment_PreAbilityUsing(eventArg, mastery, owner, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or not Mastery_Forestallment_LimitTest(mastery, owner)
		or eventArg.Ability.Type ~= 'Attack' 
		or eventArg.Ability.RelocatorMoveType == 'Flash'
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or GetInstantProperty(owner, 'Undead')
		or IsDead(eventArg.Unit)
		or owner.IsMovingNow > 0 then
		return;
	end

	local target = eventArg.Unit;
	local battleEvents = {{Object = owner, EventType = mastery.name}};
	local resultModifier = {ReactionAbility = true, Forestallment=true, BattleEvents = battleEvents};
	local directingConfig = table.deepcopy(eventArg.DirectingConfig);
	directingConfig.MessageVisible = true;
	
	-- 선의 선
	local mastery_AcuityForestallment = GetMasteryMastered(GetMastery(owner), 'AcuityForestallment');
	if mastery_AcuityForestallment then
		resultModifier['Inevitable'] = true;
		resultModifier['CriticalHit'] = true;
	end	
	
	local success, action = GetMeleeAbilityUseAction(owner, target, resultModifier, directingConfig);
	if not success then
		return;
	end
	
	if eventArg.DirectingConfig.Preemptive then
		local eventCmd = eventArg.RealActionID;
		action.directing_config.Preemptive = eventArg.DirectingConfig.Preemptive;
		action.directing_config.PreemptiveOrder = 0;
		action.nonsequential = true;
		action._overtake_ref = eventCmd;
		action._ref_offset = -1;
	end

	mastery.CountChecker = mastery.CountChecker + 1;
	action.on_fail_actions = {Result_DirectingScript(function(mid, ds, args)
		mastery.CountChecker = mastery.CountChecker - 1;
	end)};
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'PreAbilityUsing'});
	return action;
end
-- 자동 제압 사격
function Mastery_Module_ForestallmentFire_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or mastery.DuplicateApplyChecker > 0
		or eventArg.Ability.Type ~= 'Attack' 
		or eventArg.Ability.RelocatorMoveType == 'Flash'
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not IsMeleeDistance(GetPosition(owner), GetPosition(eventArg.Unit))
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or owner.IsMovingNow > 0 then
		return;
	end
	local limit = mastery.ApplyAmount4;
	-- 향상된 자동 제압 사격
	local mastery_Module_EnhancedForestallmentFire = GetMasteryMastered(GetMastery(owner), 'Module_EnhancedForestallmentFire');
	if mastery_Module_EnhancedForestallmentFire then
		limit = limit + mastery_Module_EnhancedForestallmentFire.ApplyAmount;
	end
	if mastery.CountChecker >= limit then
		return;
	end
	local actions = {};
	if owner.Cost < mastery.ApplyAmount3 then
		return;
	end
	local alreadyHitSet = GetInstantProperty(owner, mastery.name) or {};
	if alreadyHitSet[GetObjKey(eventArg.Unit)] then
		return;
	end	
	local overwatch = FindAbility(owner, owner.OverwatchAbility_Force);
	if overwatch == nil or not IsAvailableAbility(owner, overwatch) then
		return false;
	end
	local rangeClsList = GetClassList('Range');
	local range = CalculateRange(owner, overwatch.TargetRange, GetPosition(owner));
	local p = GetPosition(eventArg.Unit);
	if not PositionInRange(range, p) then
		return false;
	end
	alreadyHitSet[GetObjKey(eventArg.Unit)] = true;
	SetInstantProperty(owner, mastery.name, alreadyHitSet);
	
	local battleEvents = {};
	table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedCustomEvent', Args = {Mastery = mastery.name, EventType = 'Beginning', MissionChat = true} });
	-- Cost 증가
	local applyAct = mastery.ApplyAmount2;
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
	if action then
		ds:WorldAction(action, true);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	-- 어빌리티 사용
	local targetPos = GetPosition(eventArg.Unit);
	local abilityAction = Result_UseAbilityTarget(owner, overwatch.name, eventArg.Unit, {ReactionAbility=true, CloseCheckFire=true, BattleEvents = battleEvents, InvokeMastery = mastery.name}, true, {NoCamera = true});
	abilityAction.free_action = true;
	abilityAction.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, overwatch.TargetRange, GetPosition(owner)), targetPos);
	end;
	table.insert(actions, abilityAction);
	
	AddActionCostForDS(actions, owner, -mastery.ApplyAmount3, true, nil, ds);
	
	mastery.CountChecker = mastery.CountChecker + 1;
	return unpack(actions);
end
-- 특성 기적
function Mastery_Miracle_PreAbilityUsing(eventArg, mastery, owner, ds)
	if (eventArg.Ability.Type ~= 'Heal' and eventArg.Ability.Type ~= 'Assist')
		or (eventArg.Ability.Type == 'Assist' and eventArg.Ability.Cost <= 0)
		or eventArg.Ability.ItemAbility	then
		return;
	end
	local applyAmount = mastery.ApplyAmount;
	local masteryTable = GetMastery(owner);
	-- 헌신적인 사랑
	local mastery_InfinityLove = GetMasteryMastered(masteryTable, 'InfinityLove');
	if mastery_InfinityLove then
		applyAmount = applyAmount + mastery_InfinityLove.ApplyAmount;
	end
	if not RandomTest(applyAmount) then
		SetInstantProperty(owner, 'Miracle', nil);
		return;
	end
	
	SetInstantProperty(owner, 'Miracle', true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'PreAbilityUsing'});	
	ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name });
end
-- 재소탕
function Mastery_Resweeping_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force'
		or eventArg.Ability.SubType ~= 'Piercing' then
		return;
	end
	local targetList = nil;
	if IsStableAttack(owner) then
		local targetPos = eventArg.PositionList[#(eventArg.PositionList)];
		local applyTargets = table.filter(BuildApplyTargetInfos(owner, eventArg.Ability, targetPos), function(info)
			return info.Object and IsEnemy(owner, info.Object);
		end);
		if #applyTargets >= mastery.ApplyAmount2 then
			targetList = table.map(applyTargets, function(info) return GetObjKey(info.Object) end);
		end
	end
	SetInstantProperty(owner, mastery.name, targetList);
end
-- 연환계
function Mastery_ChainTactics_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	SubscribeWorldEvent(owner, 'ActionDelimiter', function(eventArg, ds, subscriptionID)
		UnsubscribeWorldEvent(owner, subscriptionID);
		mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
	end);
end
-- 사냥꾼과 사냥개
function Mastery_HunterAndHuntingDog_PreAbilityUsing(eventArg, mastery, owner, ds)
	if GetInstantProperty(eventArg.Unit, 'SummonMaster') ~= GetObjKey(owner) then
		return;
	end
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	mastery.CountChecker = 0;
	SubscribeWorldEvent(owner, 'ActionDelimiter', function(eventArg, ds, subscriptionID)
		UnsubscribeWorldEvent(owner, subscriptionID);
		mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
	end);
end
-- 최상위 포식자
function Mastery_ApaxPredator_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	SetInstantProperty(owner, mastery.name, owner.HP);
end
-- 나는 히어로 아이린이다!
function Mastery_ImHeroIrene_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	SetInstantProperty(owner, mastery.name, HasBuff(owner, mastery.SubBuff.name));
	mastery.DuplicateApplyChecker = 0;
end
-- 낚시왕
function Mastery_KingOfFishing_PreAbilityUsing(eventArg, mastery, owner, ds)
	if HasBuff(owner, 'ClimbWeb') then
		mastery.DuplicateApplyChecker = 1;
	else
		mastery.DuplicateApplyChecker = 0;
	end
end
-- 괴수 사냥꾼 - 3 세트
function Mastery_MonsterHunterSet3_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Trap'
		or not IsStableAttack(owner) then
		return;
	end
	mastery.CountChecker = 1;
end
------------------------------------------------------------------------------------
-- 적에게 피해를 받을때 [UnitTakeDamage]
--------------------------------------------------------------------------------------
-- 광전사
---@param eventArg unitTakeDamageEventArg
function Mastery_Berserker_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Receiver ~= owner
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') ~= 'Ability'
		or GetRelation(eventArg.Giver, owner) ~= 'Enemy'
		or eventArg.SubAction 
		or GetBuffStatus(owner, 'Unconscious', 'Or')
		or mastery.DuplicateApplyChecker > 0 
		or eventArg.Damage <= 0 then
		return;
	end
	local cnt = (GetInstantProperty(owner, 'BerserkerTarget') or {})[GetObjKey(eventArg.Giver)] or 0;
	if cnt >= mastery.ApplyAmount2 then
		return;
	end
	return Mastery_BerserkerActivated(mastery, owner, eventArg.Giver, ds);
end
-- 대설산
function Mastery_GreatSnowyMountain_UnitTakeDamage(eventArg, mastery, owner, ds)
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability'
		or eventArg.Damage <= 0 
		or eventArg.Damage > owner.MaxHP * mastery.ApplyAmount / 100 then
		return;
	end

	local actions = {};
	AddSPPropertyActionsObject(actions, owner, math.floor(mastery.CustomCacheData / mastery.ApplyAmount2) * mastery.ApplyAmount3, true, ds, true);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	return unpack(actions);
end
-- 크래미 가죽 코트
function Mastery_Coat_Crammy_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage <= owner.MaxHP * (mastery.ApplyAmount / 100) then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage_Self');
	return unpack(actions);
end
-- 고통의 망각
function Mastery_OblivionOfPain_UnitTakeDamage(eventArg, mastery, owner, ds)
	local buff = GetBuff(owner, mastery.Buff.name);
	if buff == nil
		or eventArg.Damage <= 0
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability' then
		return;
	end
	
	return Mastery_OblivionOfPain_ApplyAction(mastery, buff, owner, ds, 'UnitTakeDamage_Self');
end
-- 해골 인장
function Mastery_Amulet_Scourge_UnitTakeDamage(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	local actions = {};
	-- UseCount 감소
	local abilityName = 'Potion_Scourge';
	local ability = FindAbility(owner, abilityName);
	ability.UseCount = ability.UseCount - mastery.CountChecker;
	mastery.CountChecker = 0;
	table.insert(actions, Result_SynchronizeAbility(owner, abilityName));
	-- 부활 버프
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 동족 포식
function Mastery_Cannibalization_UnitTakeDamage(eventArg, mastery, owner, ds)
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability'
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'System'
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'SystemBuff' then
		-- 어빌리티에 의한 데미지는 여기서 처리안함 AbilityAffected를 보기
		return;
	end
	
	local invoker = owner;
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Buff' then
		invoker = GetExpTaker(SafeIndex(eventArg, 'DamageInfo', 'damage_invoker'));
	end
	
	return Mastery_Cannibalization_Test(mastery, owner, ds, invoker);
end
-- 야수 AI위협도 관련
function Buff_Beast_Loyalty_UnitTakeDamage(eventArg, mastery, owner, ds)
	local master = GetUnit(owner, GetInstantProperty(owner, 'SummonMaster'));
	if master ~= eventArg.Giver and master ~= eventArg.Receiver then
		return;
	end
	
	local aggroTarget = nil;
	local aggroAmount = 0;
	if master == eventArg.Giver then
		aggroTarget = eventArg.Receiver;
		aggroAmount = 10;
	else
		aggroTarget = eventArg.Giver;
		aggroAmount = 20;
	end
	AddHate(owner, aggroTarget, aggroAmount);
end
-- 야수 친구
function Mastery_BeastFriend_UnitTakeDamage(eventArg, mastery, owner, ds)
	local beast = SafeIndex(GetInstantProperty(owner, 'SummonBeast'), 'Target');
	if eventArg.Giver ~= eventArg.Receiver 
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Copy'
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability'
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'HPDrain'
		or (eventArg.Damage >= 0 and SafeIndex(eventArg, 'DamageInfo', 'damage_type') ~= 'Heal')
		or not beast
		or (eventArg.Receiver ~= owner and eventArg.Receiver ~= beast) then
		return;
	end
	
	local target = nil;
	local giver = nil;
	local addHP = 0;
	if eventArg.Receiver == owner then
		target = beast;
		giver = owner;
		addHP = math.floor(-eventArg.Damage * mastery.ApplyAmount2 / 100);
	else
		target = owner;
		giver = beast;
		addHP = math.floor(-eventArg.Damage * mastery.ApplyAmount / 100);
	end
	local actions = {};
	local reasons = {};
	addHP, reasons = AddActionRestoreHP(actions, giver, target, addHP, 'Copy');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage');
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	if addHP > 0 then
		DirectDamageByType(ds, target, 'Heal', -addHP, math.min(target.HP + addHP, target.MaxHP), false, false);
	end
	
	local masteryTable = GetMastery(owner);
	-- 괴수 사냥꾼
	local mastery_MonsterHunter = GetMasteryMastered(masteryTable, 'MonsterHunter');
	if mastery_MonsterHunter then
		AddActionApplyActForDS(actions, owner, owner, -mastery_MonsterHunter.ApplyAmount, ds, 'Friendly');
		AddActionApplyActForDS(actions, owner, beast, -mastery_MonsterHunter.ApplyAmount, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_MonsterHunter, owner, 'UnitTakeDamage');
	end

	-- 야수 동화
	local mastery_BeastAssimilation = GetMasteryMastered(masteryTable, 'BeastAssimilation');
	if mastery_BeastAssimilation then
		InsertBuffActions(actions, owner, owner, mastery_BeastAssimilation.Buff.name, 1, true);
		InsertBuffActions(actions, owner, beast, mastery_BeastAssimilation.Buff.name, 1, true);
		MasteryActivatedHelper(ds, mastery_BeastAssimilation, owner, 'UnitTakeDamage');
	end
	return unpack(actions);
end
-- 사냥꾼 인장
function Mastery_Amulet_Hunter_UnitTakeDamage(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker ~= 1 then
		return;
	end
	
	mastery.DuplicateApplyChecker = 2;
	return Result_RemoveBuff(owner, mastery.Buff.name);
end
-- 물러서지 않는 자 - 5 세트
function Mastery_DrakyGuardianSet5_UnitTakeDamage(eventArg, mastery, owner, ds)
	local damageInfo = eventArg.DamageInfo;
	if damageInfo and damageInfo.damage_sub_type ~= 'Etc' then
		return Result_UpdateInstantProperty(owner, mastery.name, damageInfo.damage_sub_type);
	end
end
-- 자신에게 피해를 준 대상 추적
function Mastery_SelfDamageDoner_UnitTakeDamage(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Giver)
		or owner ~= eventArg.Receiver			--- UnitTakeDamage_Self라면 이 조건은 무시해도됨
		or eventArg.Damage <= 0
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Heal' then
		return;
	end
	local applySet = GetInstantProperty(owner, mastery.name) or {};
	if applySet[GetObjKey(eventArg.Giver)] ~= nil then
		return;
	end
	applySet[GetObjKey(eventArg.Giver)] = true;
	SetInstantProperty(owner, mastery.name, applySet);
	return Result_UpdateInstantProperty(owner, mastery.name, applySet);
end
-- 마녀의 울분
function Mastery_WitchAnger_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_SelfDamageDoner_UnitTakeDamage(eventArg, mastery, owner, ds);
end
-- 시야내의 아군에게 피해를 준 대상 추적
function Mastery_AllyDamageDonerTracer_UnitTakeDamage(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Giver)
	or not IsAllyOrTeam(owner, eventArg.Receiver)
	or not IsInSight(owner, eventArg.Receiver, true)
	or eventArg.Damage <= 0
	or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Heal' then
		return;
	end
	-- 둘 다 시야 밖이면 무시
	if not IsInSight(owner, GetPosition(eventArg.Giver), true) and not IsInSight(owner, GetPosition(eventArg.Receiver), true) then
		return;
	end
	local applySet = GetInstantProperty(owner, mastery.name) or {};
	if applySet[GetObjKey(eventArg.Giver)] ~= nil then
		return;
	end
	applySet[GetObjKey(eventArg.Giver)] = true;
	SetInstantProperty(owner, mastery.name, applySet);
	return Result_UpdateInstantProperty(owner, mastery.name, applySet);
end
-- 분노의 마녀
function Mastery_WitchOfAnger_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_AllyDamageDonerTracer_UnitTakeDamage(eventArg, mastery, owner, ds);
end
-- 피의 복수
function Mastery_Vendetta_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_AllyDamageDonerTracer_UnitTakeDamage(eventArg, mastery, owner, ds);
end
-------------------
-- 헌신적인 사랑
function Mastery_InfinityLove_UnitGiveDamage(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'SupportHeal')
		or eventArg.DamageInfo.damage >= 0
		or eventArg.DamageInfo.remain_hp >= eventArg.Receiver.MaxHP
		or eventArg.DefenderState ~= 'Heal' then
		return;
	end
	local actions = {};
	local applyAct = -1 * mastery.ApplyAmount2;
	local ownerKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitGiveDamage');
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
------------------------------------------------------------------------------------
-- 적에게 피해를 입을때. [UnitTakeDamage]
--------------------------------------------------------------------------------------
-- 분홍 도깨비
function Mastery_PinkGoblin_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage <= 0 then
		return;
	end
	local applySet = GetInstantProperty(owner, mastery.name) or {};
	
	if applySet[GetObjKey(eventArg.Giver)] ~= nil then
		return;
	end
	
	applySet[GetObjKey(eventArg.Giver)] = true;
	SetInstantProperty(owner, mastery.name, applySet);
	return Result_UpdateInstantProperty(owner, mastery.name, applySet);
end
-- 특성 암석화
function Mastery_Solidification_UnitTakeDamage(eventArg, mastery, owner, ds)
	-- 어빌리티 피격 처리는 AbilityAffected 핸들러에서 진행함
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 or eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	return Mastery_Solidification_InvokeCommon(mastery, owner, ds);
end
function Mastery_Solidification_InvokeCommon(mastery, owner, ds)
	local actions = {};
	local objKey = GetObjKey(owner);
	local addLv = 1;
	local mastery_SuccessorOfGuardian = GetMasteryMastered(GetMastery(owner), 'SuccessorOfGuardian');
	if mastery_SuccessorOfGuardian then
		addLv = addLv + mastery_SuccessorOfGuardian.ApplyAmount;
	end
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, addLv);	
	
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local aniID = ds:PlayAni(objKey, 'Rage', false, -1, true);
	local sleepID = ds:Sleep(0.5);
	ds:Connect(aniID, masteryEventID, 0);
	ds:Connect(sleepID, aniID, 0);
	if mastery_SuccessorOfGuardian then
		MasteryActivatedHelper(ds, mastery_SuccessorOfGuardian, owner, '', false, masteryEventID, 0);
	end
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
function Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, damageSubType)
	-- 어빌리티 피격 처리는 AbilityAffected 핸들러에서 진행함
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 or eventArg.DamageInfo.damage_type == 'Ability' or eventArg.DamageInfo.damage_sub_type ~= damageSubType then
		return;
	end
	return Mastery_Resistance4_InvokeCommon(mastery, owner, ds);
end
function Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, damageSubType)
	if eventArg.Target ~= owner or eventArg.Ability.SubType ~= damageSubType then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	return Mastery_Resistance4_InvokeCommon(mastery, owner, ds);
end
function Mastery_Resistance4_InvokeCommon(mastery, owner, ds)
	local actions = {};
	local objKey = GetObjKey(owner);	
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true, nil, true);
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 불꽃의 가호
function Mastery_FireResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Fire');
end
function Mastery_FireResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Fire');
end
-- 얼음의 가호
function Mastery_IceResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Ice');
end
function Mastery_IceResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Ice');
end
-- 번개의 가호
function Mastery_LightningResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Lightning');
end
function Mastery_LightningResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Lightning');
end
-- 바람의 가호
function Mastery_WindResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Wind');
end
function Mastery_WindResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Wind');
end
-- 물의 가호
function Mastery_WaterResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Water');
end
function Mastery_WaterResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Water');
end
-- 대지의 가호
function Mastery_EarthResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Earth');
end
function Mastery_EarthResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Earth');
end
-- 재기의 바람
function Mastery_SecondWind_UnitTakeDamage(eventArg, mastery, owner, ds)
	-- 어빌리티 피격 처리는 AbilityAffected 핸들러에서 진행함
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 or eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	if owner.HP > owner.MaxHP * mastery.ApplyAmount2 / 100 then
		return;
	end	
	return Mastery_SecondWind_InvokeCommon(mastery, owner, ds);
end
function Mastery_SecondWind_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner then
		return;
	end
	if owner.HP > owner.MaxHP * mastery.ApplyAmount2 / 100 then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	return Mastery_SecondWind_InvokeCommon(mastery, owner, ds);
end
function Mastery_SecondWind_InvokeCommon(mastery, owner, ds)
	local actions = {};
	local objKey = GetObjKey(owner);
	local evt = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if GetBuff(owner, mastery.Buff.name) then
		local addHP = math.max(1, math.floor(owner.MaxHP * mastery.ApplyAmount/100));
		local reasons = {};
		addHP, reasons = AddActionRestoreHP(actions, owner, owner, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		actions[#actions].sequential = true;
		DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), false, false, evt, 0); 
	else
		--  재생이 없으면 재생을 건다.
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	end
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 충분한 휴식
function Mastery_MindAndBodyRest_UnitTakeDamage(eventArg, mastery, owner, ds)
	-- 어빌리티 피격 처리는 AbilityAffected 핸들러에서 진행함
	if eventArg.Receiver ~= owner or (eventArg.Damage >= 0 and eventArg.DefenderState ~= 'Heal') or eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	-- 실제 회복량이 0 이하이면서 최대 체력이라면 효율을 떨어뜨림
	local isFullHP = false;
	if eventArg.DamageInfo.damage >= 0 and owner.HP == owner.MaxHP then
		isFullHP = true;
	end	
	return Mastery_MindAndBodyRest_InvokeCommon(mastery, owner, ds, 'UnitTakeDamage_Self', isFullHP);
end
function Mastery_MindAndBodyRest_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner then
		return;
	end
	local hasAnyHeal = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Heal' and targetInfo.MainDamage <= 0;
	end);
	if not hasAnyHeal then
		return;
	end	
	local hasAnyHealEffective = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		-- 최대 HP 상태에서 들어온 회복은 효율을 떨어뜨림
		return targetInfo.DefenderState == 'Heal' and targetInfo.PrevHP < targetInfo.MaxHP;
	end);
	local isFullHP = not hasAnyHealEffective;
	return Mastery_MindAndBodyRest_InvokeCommon(mastery, owner, ds, 'AbilityAffected', isFullHP);
end
function Mastery_MindAndBodyRest_InvokeCommon(mastery, owner, ds, eventType, isFullHP)
	local actions = {};
	local objKey = GetObjKey(owner);
	local addCost = mastery.ApplyAmount;
	local applyAct = -1 * mastery.ApplyAmount2;
	-- 최대 체력 시 효과 감소
	if isFullHP then
		addCost = addCost * (1 - mastery.ApplyAmount3 / 100);
		applyAct = applyAct * (1 - mastery.ApplyAmount3 / 100);
		LogAndPrint(mastery.ApplyAmount3,addCost, applyAct);
	end
	local masteryTable = GetMastery(owner);
	-- 선혈의 기억
	local mastery_LegendOfDracula = GetMasteryMastered(masteryTable, 'LegendOfDracula');
	if mastery_LegendOfDracula then
		local applyActAdd = -1 * mastery_LegendOfDracula.ApplyAmount2;
		if isFullHP then
			applyActAdd = applyActAdd * (1 - mastery_LegendOfDracula.ApplyAmount3 / 100);
		end
		applyAct = applyAct + applyActAdd;
	end
	-- 검귀
	local mastery_GhostSword = GetMasteryMastered(masteryTable, 'GhostSword');
	if mastery_GhostSword then
		local applyActAdd = -1 * mastery_GhostSword.ApplyAmount2;
		if isFullHP then
			applyActAdd = applyActAdd * (1 - mastery_GhostSword.ApplyAmount3 / 100);
		end
		applyAct = applyAct + applyActAdd;
	end
	MasteryActivatedHelper(ds, mastery, owner, eventType);
	if mastery_LegendOfDracula then
		MasteryActivatedHelper(ds, mastery_LegendOfDracula, owner, eventType);
	end
	if mastery_GhostSword then
		MasteryActivatedHelper(ds, mastery_GhostSword, owner, eventType);
	end
	if owner.CostType.name == 'Vigor' then
		local _, reasons = AddActionCost(actions, owner, addCost, true);
		ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost });
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	elseif owner.CostType.name == 'Rage' then
		-- 행복한 포만감
		local mastery_HappyPredator = GetMasteryMastered(masteryTable, 'HappyPredator');
		if mastery_HappyPredator then
			local addCost = mastery_HappyPredator.ApplyAmount;
			local _, reasons = AddActionCost(actions, owner, addCost, true);
			ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost });
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		end
	end
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 특성 투영 - 피해 입을때 버프 복사해오기.
function Mastery_TraceOn_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local masteryTable = GetMastery(owner);
	local mastery_HappyWitch = GetMasteryMastered(masteryTable, 'HappyWitch');
	
	local target = eventArg.User;
	local targetBuffList = GetBuffType(target, 'Buff');
	local targetDebuffList = GetBuffType(target, 'Debuff');
	
	local selectBuffList = {};
	if mastery_HappyWitch then
		-- 유쾌한 마녀 (모든 버프, 디버프 선택)
		table.append(selectBuffList, targetBuffList);
		table.append(selectBuffList, targetDebuffList);
	else
		--기본 투영 효과 (버프 1개 랜덤 선택)
		if #targetBuffList > 0 then
			local selectBuff = targetBuffList[math.random(1, #targetBuffList)];
			table.insert(selectBuffList, selectBuff);
		end
	end
	if #selectBuffList <= 0 then
		return;
	end
	
	local objKey = GetObjKey(owner);
	local actions = {};
	for _, selectBuff in ipairs(selectBuffList) do
		InsertBuffActions(actions, owner, owner, selectBuff.name, selectBuff.Lv, true);
	end
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local aniID = ds:PlayAni(objKey, 'AstdIdle', false, -1, true);
	ds:Connect(masteryEventID, aniID, 0);
	if mastery_HappyWitch then
		ds:Connect(ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery_HappyWitch.name }), masteryEventID, 0);
	end
	
	-- 일그러진 마음
	local mastery_UglyMind = GetMasteryMastered(masteryTable, 'UglyMind');
	if mastery_UglyMind then
		local applyAct = -1 * math.floor(#selectBuffList / mastery_UglyMind.ApplyAmount) * mastery_UglyMind.ApplyAmount2;
		if applyAct < 0 then
			MasteryActivatedHelper(ds, mastery_UglyMind, owner, 'AbilityAffected');
			AddActionApplyActForDS(actions, owner, owner, applyAct, ds, 'Friendly', nil, nil, eventArg.Ability);
		end
	end

	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityAffected'});
	return unpack(actions);
end
-- 특성 저주
function Mastery_Curse_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	
	local buffList = GetClassList('Buff');
	local badBuffList = Linq.new(GetClassList('Buff_Negative'))
		:select(function(pair) return pair[1]; end)
		:where(function(buffName) return buffList[buffName].SubType == 'Mental'; end)
		:toList();
		
	local target = eventArg.User;
	local buffPicker = RandomBuffPicker.new(target, badBuffList);
	local buff = buffPicker:PickBuff();
	if not buff then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	InsertBuffActions(actions, owner, target, buff, 1, true);
	return unpack(actions);
end
-- 특성 무기 막기
function Mastery_WeaponBlocking_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Block';
	end);
	if not hasAnyBlock then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local masteryTable = GetMastery(owner);
	local applyAct = - mastery.ApplyAmount;
	local mastery_GuardianSword = GetMasteryMastered(masteryTable, 'GuardianSword'); 
	if mastery_GuardianSword then
		applyAct = applyAct - mastery_GuardianSword.ApplyAmount;
		ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	end
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 특성 신속한 대응
function Mastery_RapidReaction_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local applyAct = -mastery.ApplyAmount;
	local masteryTable = GetMastery(owner);
	local mastery_Opportunist = GetMasteryMastered(masteryTable, 'Opportunist');
	if mastery_Opportunist then
		applyAct = applyAct - mastery_Opportunist.ApplyAmount;
		MasteryActivatedHelper(ds, mastery_Opportunist, owner, 'AbilitAffected');
	end

	local mastery_ShakeShake = GetMasteryMastered(masteryTable, 'ShakeShake');
	if mastery_ShakeShake then
		InsertBuffActions(actions, owner, owner, mastery_ShakeShake.Buff.name, mastery_ShakeShake.ApplyAmount2);
		MasteryActivatedHelper(ds, mastery_ShakeShake, owner, 'AbilityAffected');
	end
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	
	-- 전장을 뚫어라
	local mastery_DrillBattleField = GetMasteryMastered(masteryTable, 'DrillBattleField');
	if mastery_DrillBattleField then
		InsertBuffActions(actions, owner, owner, mastery_DrillBattleField.Buff.name, 1, true);
		MasteryActivatedHelper(ds, mastery_DrillBattleField, owner, 'AbilityAffected');
	end
	
	return unpack(actions);
end
-- 특성 흐르는 물
function Mastery_RunningWater_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner then
		return;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Water', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 특성 얼어붙은 심장
function Mastery_FrozenHeart_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Block';
	end);
	if not hasAnyBlock then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Ice', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 정보 분석
function Mastery_InformationAnalysis_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Info', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityAffected'});
	return unpack(actions);
end
-- 특성 흘리기
function Mastery_Parry_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local checkDist = 1.4;
	local masteryTable = GetMastery(owner);
	local mastery_Mountain = GetMasteryMastered(masteryTable, 'Mountain');
	if mastery_Mountain then
		checkDist = mastery_Mountain.ApplyAmount;
	end
	if not IsMeleeDistanceAbility(eventArg.User, owner, checkDist) then
		return;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	local hasAnyBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Block';
	end);
	if not hasAnyDodge and not hasAnyBlock then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');	
	local giveAct;
	if hasAnyDodge then
		giveAct = mastery.ApplyAmount;
	else
		giveAct = mastery.ApplyAmount2;
	end
	AddActionApplyActForDS(actions, owner, eventArg.User, giveAct, ds, 'Hostile');
	-- 수문장
	local masteryTable = GetMastery(owner);
	local mastery_Gatekeeper = GetMasteryMastered(masteryTable, 'Gatekeeper');
	if mastery_Gatekeeper then
		AddActionApplyActForDS(actions, owner, owner, -mastery_Gatekeeper.ApplyAmount2, ds, 'Friendly');
	end
	-- 실전 호신술
	local mastery_ActualMartialArtsDefence = GetMasteryMastered(masteryTable, 'ActualMartialArtsDefence');
	if mastery_ActualMartialArtsDefence then
		local applyAmount = math.floor(mastery_ActualMartialArtsDefence.CustomCacheData / mastery_ActualMartialArtsDefence.ApplyAmount4) * mastery_ActualMartialArtsDefence.ApplyAmount5;
		AddActionApplyActForDS(actions, owner, owner, -1 * applyAmount, ds, 'Friendly');
	end
	return unpack(actions);
end
-- 특성 견제 공격
function Mastery_ContainingAttack_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 then
			local target = targetInfo.Target;
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	local applyAct = mastery.ApplyAmount;
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	for targetKey, target in pairs(applyTargets) do
		local added, reasons = AddActionApplyAct(actions, target, target, applyAct, 'Hostile', nil, eventArg.Ability);
		if added then
			ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(target, ds, reasons);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 특성 그물 속의 먹잇감
function Mastery_FoodinWeb_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 and HasBuff(targetInfo.Target, 'Web') then
			local target = targetInfo.Target;
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	-- 끈끈한 거미줄 주머니
	local mastery_StickyWebSac = GetMasteryMastered(GetMastery(owner), 'StickyWebSac');
	local stickyWebSacActivated = false;

	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	for targetKey, target in pairs(applyTargets) do
		local applyAct = mastery.ApplyAmount;
		if mastery_StickyWebSac and HasBuff(target, mastery_StickyWebSac.SubBuff.name) then
			applyAct = applyAct + mastery_StickyWebSac.ApplyAmount2;
			stickyWebSacActivated = true;
		end
		local added, reasons = AddActionApplyAct(actions, target, target, applyAct, 'Hostile', nil, eventArg.Ability);
		if added then
			ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(target, ds, reasons);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed_Self'});
	if stickyWebSacActivated then
		MasteryActivatedHelper(ds, mastery_StickyWebSac, owner, 'AbilityUsed_Self');
	end
	return unpack(actions);
end
-- 기회 포착
function Mastery_OpportunityAcquisition_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDodgeOrBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge' or targetInfo.DefenderState == 'Block';
	end);
	if not hasAnyDodgeOrBlock then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
function Direct_ObstacleDisabled(mid, ds, args)
	local objKey = args.ObjKey;
	local playId = ds:PlayUIEffect(objKey, '', 'BigText', 0, 0, PackTableToString({Text = WordText('ObstacleDisabled'), Color = 'FFFFFFCC'}));
	ds:SetCommandLayer(playId, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(playId);
end
function ReplaceMonster(ds, mon, replaceMonType, playDead, inheritTeam)
	local direction = GetDirection(mon);
	local newObjKey = GenerateUnnamedObjKey(GetMission(mon));
	local destroy = Result_DestroyObject(mon, false, true);
	local team = '_neutral_';
	if inheritTeam then
		team = GetTeam(mon);
	end
	local create = Result_CreateMonster(newObjKey, replaceMonType, GetPosition(mon), team, function(obj, arg)
		UNIT_INITIALIZER(obj, GetTeam(obj));
		SetDirection(obj, direction);
	end, nil, 'DoNothingAI', {}, true);
	destroy.sequential = true;
	create.sequential = true;
	if playDead then
		local eventID = ds:SetDead(GetObjKey(mon), 'Normal', 0, 0, 0, 0, 0);
		destroy._ref = eventID;
		destroy._ref_offset = -1;
		create._ref = eventID;
		create._ref_offset = -1;
	end
	return {destroy, create}, newObjKey;
end
function Mastery_FlammableObject_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_base <= 0 then
		return;
	end
	if eventArg.DamageInfo.damage_sub_type == 'Ice' then
		local disabledMonType = GetInstantProperty(owner, 'DisabledMonsterType');
		if not disabledMonType then
			LogAndPrint('Cannot find DisabledMonsterType', owner.name, GetObjKey(owner));
			return;
		end
		local actions, newObjKey = ReplaceMonster(ds, owner, disabledMonType, false);
		local directing = Result_DirectingScript('Direct_ObstacleDisabled', {ObjKey = newObjKey});
		directing.sequential = true;
		table.insert(actions, directing);
		return unpack(actions);
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
	local abilityBuff = eventArg.DamageInfo.damage_type == 'Ability';
	if not abilityBuff then
		ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', {Buff = 'Burning'});
	end
	if eventArg.Giver == owner then
		return;
	end
	return Result_AddBuff(owner, owner, 'Burning', 1, nil, true, abilityBuff);
end
function Mastery_ToxicObject_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_base <= 0 then
		return;
	end
	if eventArg.DamageInfo.damage_sub_type == 'Ice' then
		local disabledMonType = GetInstantProperty(owner, 'DisabledMonsterType');
		local direction = GetDirection(owner);
		local newObjKey = GenerateUnnamedObjKey(GetMission(owner));
		local destroy = Result_DestroyObject(owner, false, true);
		local create = Result_CreateMonster(newObjKey, disabledMonType, GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		local directing = Result_DirectingScript('Direct_ObstacleDisabled', {ObjKey = newObjKey});
		destroy.sequential = true;
		create.sequential = true;
		directing.sequential = true;
		return destroy, create, directing;
	end
	
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
	return Result_AddBuff(owner, owner, 'Burning', 1, nil, true, false), Result_UseAbility(owner, 'ToxicLeakage', GetPosition(owner), nil, true);
end
function Mastery_Civil_UnitTurnEnd(eventArg, mastery, owner, ds)
	local team = GetTeam(eventArg.Unit);
	if team == 'citizen'
		or team == 'player'
		or string.find(team, '[e|E]nemy') == nil
		or eventArg.Unit.Race.name == 'Object'
		or GetDistance3D(GetPosition(owner), GetPosition(eventArg.Unit)) >= 2 then
		return;
	end
	
	local unitKey = GetObjKey(owner);
	ds:ChangeCameraTarget(unitKey, '_SYSTEM_', false)
	ds:UpdateBalloonCivilMessage(unitKey, 'Feared', owner.Info.AgeType);
	
	local injured = GetBuff(owner, 'InjuredRescue') or GetBuff(owner, 'InjuredRageRescue');
	
	if injured then
		return;
	end
	
	local pos = FindAIMovePosition(owner, {FindMoveAbility(owner)}, function(self, adb, args)
		if adb.MoveDistance > 3 then
			return -9999;
		end
		
		local score = 0;
		if adb.Coverable then
			score = score + 1000;
		end
		
		if not adb.ClearPath then
			score = score + 500;
		end
		return score + math.min(adb.MinBadFieldDistance, adb.MinEnemyDistance);
	end, {}, {});
	if pos == nil then
		return;
	end
	ds:ReserveMove(unitKey, pos, nil, false, nil, nil, true);
end
function Mastery_HardshipWay_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(eventArg.User, owner)
		or owner.HP <= 0 then
		return;
	end
	local hasNotDodgeAndDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0;
	end);
	if not hasNotDodgeAndDamage then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = -mastery.ApplyAmount });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	return unpack(actions);
end
-- 특성 아르고노트
function Mastery_Argonaut_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(eventArg.User, owner)
		or owner.HP <= 0 then
		return;
	end
	local hasNotDodgeAndDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0;
	end);
	if not hasNotDodgeAndDamage then
		return;
	end
	if owner.HP > owner.MaxHP * mastery.ApplyAmount / 100 then
		return;
	end
	if owner.Overcharge > 0 then
		return;
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	AddSPPropertyActions(actions, owner, owner.ESP.name, owner.MaxSP - owner.SP, true, ds, true);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 특성 에너지 전환.
function Mastery_ConversionOfEnergy_UnitTakeDamage(eventArg, mastery, owner, ds)
	if not IsEnemy(eventArg.Giver, owner)
		or eventArg.DefenderState == 'Dodge'
		or eventArg.Damage <= 0
		or owner.HP <= 0 
		or eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	return Mastery_ConversionOfEnergy_InvokeCommon(mastery, owner, ds, eventArg.Damage);
end
function Mastery_ConversionOfEnergy_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(eventArg.User, owner)
		or owner.HP <= 0 then
		return;
	end
	local totalDamage = 0;
	ForeachAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		if targetInfo.MainDamage > 0 then
			totalDamage = totalDamage + targetInfo.MainDamage;
		end
	end);
	if totalDamage <= 0 then
		return;
	end
	return Mastery_ConversionOfEnergy_InvokeCommon(mastery, owner, ds, totalDamage);
end
function Mastery_ConversionOfEnergy_InvokeCommon(mastery, owner, ds, damage)
	if damage < owner.MaxHP * mastery.ApplyAmount / 100 then
		return;
	end
	local actions = {};
	local addsp = math.max(1, math.floor(damage * mastery.ApplyAmount2/100));
	
	local masteryTable = GetMastery(owner);
	local mastery_Generator = GetMasteryMastered(masteryTable, 'Generator');
	if mastery_Generator then
		addsp = addsp + mastery_Generator.ApplyAmount2;
	end	
	local mastery_AuxiliaryPower = GetMasteryMastered(GetMastery(owner), 'AuxiliaryPower');
	if mastery_AuxiliaryPower and addsp > 0 then
		InsertBuffActions(actions, owner, owner, mastery_AuxiliaryPower.Buff.name, addsp, true);
		MasteryActivatedHelper(ds, mastery_AuxiliaryPower, owner, 'Etc');
	end
	
	local objKey = GetObjKey(owner);
	AddSPPropertyActions(actions, owner, owner.ESP.name, addsp, true, ds, true);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 연료 전환
function Mastery_Module_ConversionOfFuel_UnitTakeDamage(eventArg, mastery, owner, ds)
	if not IsEnemy(eventArg.Giver, owner)
		or eventArg.DefenderState == 'Dodge'
		or eventArg.Damage <= 0
		or owner.HP <= 0 
		or eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	return Mastery_Module_ConversionOfFuel_InvokeCommon(mastery, owner, ds, eventArg.Damage, 'UnitTakeDamage_Self');
end
function Mastery_Module_ConversionOfFuel_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(eventArg.User, owner)
		or owner.HP <= 0 then
		return;
	end
	local totalDamage = 0;
	ForeachAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		if targetInfo.MainDamage > 0 then
			totalDamage = totalDamage + targetInfo.MainDamage;
		end
	end);
	if totalDamage <= 0 then
		return;
	end
	return Mastery_Module_ConversionOfFuel_InvokeCommon(mastery, owner, ds, totalDamage, 'AbilityAffected');
end
function Mastery_Module_ConversionOfFuel_InvokeCommon(mastery, owner, ds, damage, eventType)
	if damage < owner.MaxHP * mastery.ApplyAmount / 100 then
		return;
	end
	local actions = {};
	local applyAmount = mastery.ApplyAmount2;
	local multiplier = 0;
	if owner.ESP and owner.ESP.name == 'Charge' then
		multiplier = multiplier + mastery.ApplyAmount3;
	end
	-- 연비 제어 프로그램
	local mastery_Module_FuelEnhancement = GetMasteryMastered(GetMastery(owner), 'Module_FuelEnhancement');
	if mastery_Module_FuelEnhancement then
		multiplier = multiplier + mastery_Module_FuelEnhancement.ApplyAmount2;
	end
	if multiplier > 0 then
		applyAmount = applyAmount * (1 + multiplier / 100);
	end
	local addCost = math.max(1, math.floor(damage * applyAmount/100));
	local _ reasons = AddActionCost(actions, owner, addCost, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = addCost });
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	MasteryActivatedHelper(ds, mastery, owner, eventType);
	if mastery_Module_FuelEnhancement then
		MasteryActivatedHelper(ds, mastery_Module_FuelEnhancement, owner, eventType);
	end
	
	return unpack(actions);
end
-- 특성 보이지 않는 검, 감춰진 살의, 선수필승
function Mastery_CommonBattleTargets_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local battleTargets = GetInstantProperty(owner, mastery.name) or {};
	local targetKey = GetObjKey(eventArg.User);
	battleTargets[targetKey] = true;
	return Result_UpdateInstantProperty(owner, mastery.name, battleTargets);
end
function Mastery_SpellPowerOfCrack_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasDodgeOrBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge' or targetInfo.DefenderState == 'Block';
	end);
	if not hasDodgeOrBlock then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	
	local addlv = 1;
	local mastery_SpellAcceleration = GetMasteryMastered(GetMastery(owner), 'SpellAcceleration');
	if mastery_SpellAcceleration then
		MasteryActivatedHelper(ds, mastery_SpellAcceleration, owner, 'AbilityAffected');
		addLv = addlv + mastery_SpellAcceleration.ApplyAmount;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, addLv, true, nil, nil, {Type = 'Mastery', Value = mastery.name});
	return unpack(actions);
end
-- 인공지능 모듈 - 회피 기동
function Get_MovePosition_EscapeMove(owner, target, moveDist)
	local distance = moveDist;
	distance = distance + 0.4;
	
	local pos, score, _ = FindAIMovePosition(owner, {FindMoveAbility(owner)}, function (self, adb)
		if adb.MoveDistance > distance then
			return -100;	-- 거리제한
		end
		if adb.BadField then
			return -1357;
		end
		
		local totalScore = 1000;
		local accuracyScore = adb.Accuracy;
		local allyDensityScore = adb.AllyDensity(2);
		local moveDistanceScore = adb.MoveDistance;
		local targetDistanceScore = GetDistance3D(adb.Position, GetPosition(target));
		local dangerousScore = adb.Dangerous;
		
		-- 대상과 먼 곳으로 간다.
		totalScore = totalScore + targetDistanceScore * 5;
		
		-- 가능하면 조금 더 안전한 곳으로
		totalScore = totalScore + dangerousScore;
		
		-- 아군이 붙는 곳을 싫어한다 ( 연출용 )
		totalScore = totalScore - allyDensityScore;
		-- 최대한 현재 위치에서 적게 움직이려고 한다.( 연출용 )
		totalScore = totalScore - moveDistanceScore;
		
		return totalScore;
	end, {}, {});
	
	if (not pos) or (score <= 0) or IsSamePosition(pos, GetPosition(owner)) then
		return nil;
	end
	
	return pos;	
end
-- 자동 회피 기동
function Mastery_Module_EscapeMove_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(eventArg.User, owner)
		or not owner.Movable
		or eventArg.SubAction
		or GetBuffStatus(owner, 'Unconscious', 'Or')
		or owner.HP <= 0
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	if owner.Cost < mastery.ApplyAmount then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	
	local moveDist = owner.MoveDist / 2;
	local pos = Get_MovePosition_EscapeMove(owner, eventArg.User, moveDist);
	if pos then
		ds:ReserveMove(objKey, pos, 'Rush', false, moveDist, moveDist, true, {Type = 'Mastery', Value = mastery.name, Unit = eventArg.User});
		AddActionCostForDS(actions,  owner, -mastery.ApplyAmount, true, nil, ds);
		mastery.DuplicateApplyChecker = 1;
	end
	return unpack(actions);
end
-- 교란
function Mastery_Feint_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return;
	end
	local applyAct = mastery.ApplyAmount;
	if eventArg.Ability.TargetType ~= 'Single' then
		applyAct = mastery.ApplyAmount2;
	end
	local actions = {};
	local target = eventArg.User;
	local targetKey = GetObjKey(target);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	local added, reasons = AddActionApplyAct(actions, target, target, applyAct, 'Hostile', nil, eventArg.Ability);
	if added then
		ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(target, ds, reasons);
	-- 교란 공격
	local mastery_FeintAttack = GetMasteryMastered(GetMastery(owner), 'FeintAttack');
	if mastery_FeintAttack and RandomTest(mastery_FeintAttack.ApplyAmount2) then
		MasteryActivatedHelper(ds, mastery_FeintAttack, owner, 'AbilityAffected');
		local buffTurn = mastery_FeintAttack.Buff.Turn;
		buffTurn = buffTurn + mastery_FeintAttack.ApplyAmount;
		InsertBuffActionsModifier(actions, owner, target, mastery_FeintAttack.Buff.name, 1, buffTurn, true, nil, true);
	end
	return unpack(actions);
end
-- 돌입준비
function IsDodgeOnCover_AbilityAffected(eventArg, owner)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' then
		return false;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return false;
	end
	local coverState = GetCoverStateForCritical(owner, GetMastery(owner), GetPosition(eventArg.User), eventArg.User);
	if coverState == 'None' then
		return false;
	end
	return true;
end
function Mastery_RushReady_AbilityAffected(eventArg, mastery, owner, ds)
	if not IsDodgeOnCover_AbilityAffected(eventArg, owner) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	local applyAmount = mastery.ApplyAmount;
	-- 완벽한 잠복
	local mastery_PerfectCover = GetMasteryMastered(GetMastery(owner), 'PerfectCover');
	if mastery_PerfectCover then
		applyAmount = applyAmount + mastery_PerfectCover.ApplyAmount2;
	end
	local applyAct = -1 * applyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly', nil, eventArg.Ability);
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 붉은 꽃
function Mastery_Amulet_Flower_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_CriticalRageBuff_AbilityAffected(eventArg, mastery, owner, ds);
end
-- 다혈질
function Mastery_HotTempered_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_CriticalRageBuff_AbilityAffected(eventArg, mastery, owner, ds);
end
function Mastery_CriticalRageBuff_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyCritical = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.AttackerState == 'Critical' and targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0;
	end);
	if not hasAnyCritical then
		return;
	end
	local dataList = GetClassList('Buff_'..mastery.BuffGroup.name);
	if not dataList then
		LogAndPrint('Random BuffGroup is not defined -:', mastery.BuffGroup.name);
		return;
	end
	local rageBuffList = Linq.new(dataList)
		:select(function(pair) return pair[1]; end)
		:toList();
	local buffPicker = RandomBuffPicker.new(owner, rageBuffList);
	local pickBuff = buffPicker:PickBuff();
	if not pickBuff then
		return;
	end	
	local actions = {};
	local objKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	InsertBuffActions(actions, owner, owner, pickBuff, 1, true);
	return unpack(actions);
end
-- 마법 재구성
function Mastery_MagicReconstitution_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local flagSet = Set.new();
	ForeachAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		local testFlags = table.filter({ 'IronHeart', 'MagicField', 'ImpulseFields' }, function(flag)
			return SafeIndex(targetInfo.DamageFlag, flag);
		end);
		flagSet:union(Set.new(testFlags));
	end);
	local testFlags = flagSet:getKeys();
	if #testFlags == 0 then
		return;
	end
	local addLv = #testFlags;
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, addLv, true, nil, nil, {Type = 'Mastery', Value = mastery.name});
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	return unpack(actions);
end
-- 충격흡수
function Mastery_Module_ShockAbsorber_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_type ~= 'Ability' then
		return;
	end
	local testFlags = table.filter({ 'Module_ShockAbsorber' }, function(flag)
		return SafeIndex(eventArg, 'DamageInfo', 'Flag', flag);
	end);
	if #testFlags == 0 then
		return;
	end
	local actions = {};
	local addCost = -1 * mastery.ApplyAmount2;
	local _ reasons = AddActionCost(actions, owner, addCost, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = addCost });
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 마력 보호막
function Mastery_MagicArmor_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_type ~= 'Ability' then
		return;
	end
	local testFlags = table.filter({ 'MagicArmor' }, function(flag)
		return SafeIndex(eventArg, 'DamageInfo', 'Flag', flag);
	end);
	if #testFlags == 0 then
		return;
	end

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	local addCost = -1 * mastery.ApplyAmount2;

	-- 개량된 마력 보호막
	af:AddSynergyMasteryAction(owner, 'EnhancedMagicArmor', function(mastery_EnhancedMagicArmor)
		addCost = addCost + mastery_EnhancedMagicArmor.ApplyAmount;
	end);

	-- 특성 아발론의 가호
	af:AddSynergyMasteryAction(owner, 'AvalonArmor', function(mastery_AvalonArmor)
		af:InsertBuff(owner, owner, mastery_AvalonArmor.Buff.name, 1);
	end);

	af:AddCost(owner, addCost, true);

	return af:UnpackActions('UnitTakeDamage_Self');
end
-- 맹독 가죽
function Mastery_PoisonSkin_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack'
		or not IsMeleeDistance(GetPosition(owner), GetPosition(eventArg.User)) then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local target = eventArg.User;
	local buffList = GetClassList('Buff');
	local poisonBuffList = Linq.new(GetClassList('Buff_Poison'))
		:where(function(pair)
			local buff = buffList[pair[1]];
			return buff.Type == 'Debuff' and buff.SubType ~= 'Aura'; end)
		:select(function(pair) return pair[1]; end)
		:toList();
		
	local buffPicker = RandomBuffPicker.new(target, poisonBuffList);
	local pickBuff = buffPicker:PickBuff();
	if not pickBuff then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	InsertBuffActions(actions, owner, target, pickBuff, 1, true);

	-- 화려한 맹독 가죽
	local mastery_EnhancedPoisonSkin = GetMasteryMastered(GetMastery(owner), 'EnhancedPoisonSkin');
	if mastery_EnhancedPoisonSkin then
		InsertBuffActions(actions, owner, target, mastery_EnhancedPoisonSkin.Buff.name, 1);
		MasteryActivatedHelper(ds, mastery_EnhancedPoisonSkin, owner, 'AbilityAffected');
	end
	return unpack(actions);
end
-- 정전기
function Mastery_StaticElectricity_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack'
		or not IsMeleeDistance(GetPosition(owner), GetPosition(eventArg.User)) then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end

	-- 승압
	local damage = mastery.ApplyAmount;
	local mastery_RaiseVoltage = GetMasteryMastered(GetMastery(owner), 'RaiseVoltage');
	if mastery_RaiseVoltage then
		damage = damage + mastery_RaiseVoltage.ApplyAmount3;
	end

	local masteryTable = GetMastery(owner);
	local actions = {};
	local damTargets = {};
	table.insert(damTargets, eventArg.User);
	local mastery_AuxiliaryPower = GetMasteryMastered(masteryTable, 'AuxiliaryPower');
	if mastery_AuxiliaryPower == nil then
		table.insert(damTargets, owner);
	else
		MasteryActivatedHelper(ds, mastery_AuxiliaryPower, owner, 'AbilityAffected');
	end
	-- 정전기 가죽
	local mastery_EnhancedLightningSkin = GetMasteryMastered(masteryTable, 'EnhancedLightningSkin');
	if mastery_EnhancedLightningSkin then
		MasteryActivatedHelper(ds, mastery_EnhancedLightningSkin, owner, 'AbilityAffected');
	end
	for _, target in ipairs(damTargets) do
		local realDamage, reasons = ApplyDamageTest(target, damage, 'Mastery');
		local isDead = target.HP <= realDamage;
		local remainHP = math.clamp(target.HP - realDamage, 0, target.MaxHP);
		DirectDamageByType(ds, target, 'StaticElectricity', damage, remainHP, true, isDead);
		ReasonToUpdateBattleEventMulti(target, ds, reasons);
		local damageAction = Result_Damage(damage, 'Normal', 'Hit', owner, target, 'Mastery', 'Lightning', mastery);
		damageAction.sequential = true;
		table.insert(actions, damageAction);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEventTargetDamage', {ObjectKey = GetObjKey(owner), TargetKey = GetObjKey(target), MasteryType = mastery.name, Damage = damage});
		if mastery_EnhancedLightningSkin then
			InsertBuffActions(actions, owner, target, mastery_EnhancedLightningSkin.Buff.name, 1, true);
		end
	end
	-- 생체 자가 발전
	local mastery_BioelectricitySpark = GetMasteryMastered(masteryTable, 'BioelectricitySpark');
	if mastery_BioelectricitySpark then
		InsertBuffActions(actions, owner, owner, mastery_BioelectricitySpark.Buff.name, mastery_BioelectricitySpark.CustomCacheData, true);
		MasteryActivatedHelper(ds, mastery_BioelectricitySpark, owner, 'AbilityAffected');
	end
	return unpack(actions);
end
-- 축전기
function Mastery_Capacitor_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage <= 0
		or owner.HP <= 0 then
		return;
	end
	local actions = {};
	local addLv = eventArg.Damage;
	local mastery_BigCapacitor = GetMasteryMastered(GetMastery(owner), 'BigCapacitor');
	if mastery_BigCapacitor then
		addLv = math.floor(addLv * (1 + mastery_BigCapacitor.ApplyAmount / 100));
		MasteryActivatedHelper(ds, mastery_BigCapacitor, owner, 'UnitTakeDamage_Self');
	end
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, addLv, true, nil, nil, {Type = 'Mastery', Value = mastery.name});
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage_Self');
	return unpack(actions);
end
-- 긴급 구동
function Mastery_Module_EmergencyMode_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage <= 0
		or owner.HP <= 0 then
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	if eventArg.Damage <= owner.MaxHP * mastery.ApplyAmount/100 then
		return;
	end
	if owner.Cost < mastery.ApplyAmount2 then
		return;
	end
	if not owner.TurnState.TurnEnded and owner.Act <= 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage_Self');
	AddActionCostForDS(actions, owner, -mastery.ApplyAmount2, true, nil, ds);
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	-- 자율 행동 강화 프로그램
	local mastery_Module_AutoAction = GetMasteryMastered(GetMastery(owner), 'Module_AutoAction');
	if mastery_Module_AutoAction then
		-- 바로 턴 대기시간을 줄일 수 없으므로, 턴 획득 시까지 지연시킴
		SubscribeWorldEvent(owner, 'UnitTurnAcquired', function(eventArg, ds, subscriptionID)
			if eventArg.Unit ~= owner then
				return;
			end
			UnsubscribeWorldEvent(owner, subscriptionID);
			local actions = {};
			AddActionApplyActForDS(actions, owner, owner, -mastery_Module_AutoAction.ApplyAmount2, ds, 'Friendly');
			MasteryActivatedHelper(ds, mastery_Module_AutoAction, owner, 'UnitDead');
			return unpack(actions);
		end);
	end	
	return unpack(actions);
end
-- 드라키의 화려한 비늘
function Mastery_Amulet_Draky_Scale_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage <= 0
		or owner.HP <= 0 then
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	if eventArg.Damage < owner.MaxHP * mastery.ApplyAmount/100 then
		return;
	end
	if not owner.TurnState.TurnEnded and owner.Act <= 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage_Self');
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	return unpack(actions);
end
-- 바위 망치
function Mastery_StoneHammer_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_type ~= 'Ability' then
		return;
	end
	local testFlags = table.filter({ 'RockCastle' }, function(flag)
		return SafeIndex(eventArg, 'DamageInfo', 'Flag', flag);
	end);
	if #testFlags == 0 then
		return;
	end
	-- 다시 걸어줄 필요 없음
	local buff = GetBuff(owner, mastery.SubBuff.name);
	if buff and buff.Life >= buff.Turn then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, true);
	return unpack(actions);
end
-- 아발론의 가호
function Mastery_AvalonArmor_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	if mastery.CountChecker <= 0 then
		return;
	end
	mastery.CountChecker = 0;
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');	
	AddActionCostForDS(actions, owner, -1 * owner.Cost, true, nil, ds);
	return unpack(actions);
end
-- 성전
function Mastery_HolyWar_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage <= 0 then
		return;
	end
	local targetKey = GetObjKey(eventArg.Giver);
	local applySet = GetInstantProperty(owner, mastery.name) or {};
	if applySet[targetKey] ~= nil then
		return;
	end
	applySet[targetKey] = true;
	SetInstantProperty(owner, mastery.name, applySet);
	return Result_UpdateInstantProperty(owner, mastery.name, applySet);
end
------------------------------------------------------------------------------------
-- 액션 구분자 [ActionDelimiter]
--------------------------------------------------------------------------------------
-- 약자 멸시
function Mastery_CustomCacheInvalidater(eventArg, mastery, owner, ds)
	if not IsKeyInstanced(mastery, 'CustomCacheData') then
		return;
	end
	return Result_InvalidateMastery(owner, mastery.name, 'CustomCacheData');
end
-- 광전사
function Mastery_Berserker_ActionDelimiter(eventArg, mastery, owner, ds)
	SetInstantProperty(owner, 'BerserkerTarget', nil);
	mastery.DuplicateApplyChecker = 0;
end
-- 영혼 인도자
function Mastery_SoulGuide_ActionDelimiter(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker == 0 then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local cam = ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	
	local addCostVal = mastery.ApplyAmount * mastery.DuplicateApplyChecker;
	local guardian = GetMasteryMastered(GetMastery(owner), 'SoulGuardian');
	if guardian then
		addCostVal = addCostVal + guardian.ApplyAmount * mastery.DuplicateApplyChecker;
	end
	
	local afterCost, reasons = AddActionCost(actions, owner, addCostVal, true);
	if owner.Cost < afterCost then
		ds:Connect(ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = afterCost - owner.Cost }), cam, 0.5);
	end
	ds:Connect(ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name }), cam, 0.5);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons, cam, 0.5);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'ActionDelimiter'});
	
	local mastery_SoulReaper = GetMasteryMastered(GetMastery(owner), 'SoulReaper');
	if mastery_SoulReaper then
		InsertBuffActions(actions, owner, owner, mastery_SoulReaper.Buff.name, mastery.DuplicateApplyChecker);
		MasteryActivatedHelper(ds, mastery, owner, 'ActionDelimiter', nil, cam, 0.5);
	end
	mastery.DuplicateApplyChecker = 0;
	return unpack(actions);
end
-- 사령술사 팔찌
function Mastery_Bangle_EtrosPriest_Legend_ActionDelimiter(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker == 0 then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local cam = ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, math.floor(mastery.DuplicateApplyChecker/mastery.ApplyAmount));
	MasteryActivatedHelper(ds, mastery, owner, 'ActionDelimiter', nil, cam, 0.5);
	mastery.DuplicateApplyChecker = 0;
	return unpack(actions);
end
-- 배움의 기쁨
function Mastery_RoadOfStudies_ActionDelimiter(eventArg, mastery, owner, ds)
	return Mastery_RoadOfStudies_FlushPrevExp(eventArg, mastery, owner, ds);
end
-- 기계장인 가죽 자켓
function Mastery_Jacket_Mechanic_Set_ActionDelimiter(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	local actions = {};
	mastery.CountChecker = 0;
	MasteryActivatedHelper(ds, mastery, owner, 'ActionDelimiter');
	AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount, ds, 'Friendly');
	return unpack(actions);
end
--------------------------------------------------------------------------------------------
-- 유닛을 죽임 [UnitKilled]
--------------------------------------------------------------------------------------------
-- 비틀린 쾌락
---@param mastery class_Mastery
---@param eventArg unitKilledEventArg
---@param owner unit
---@param ds DirectingScripter
function Mastery_BrutalityTargetWeakMan_UnitKilled(eventArg, mastery, owner, ds)
	if GetObjKey(eventArg.Unit) ~= mastery.RefPersonType then
		return;
	end

	local af = MasteryActionFactory.new(ds)
	af:AddActivator(mastery, owner);
	af:InsertBuff(owner, owner, mastery.Buff.name, 1);
	return af:UnpackActions('UnitKilled_Self');
end
-- 거미줄 만찬
---@param mastery class_Mastery
---@param eventArg unitKilledEventArg
---@param owner unit
---@param ds DirectingScripter
function Mastery_WebDinners_UnitKilled(eventArg, mastery, owner, ds)
	if not table.exist(GetFieldEffectByPosition(owner, GetPosition(eventArg.Unit)), function(fei) return fei.Owner.name == 'Web' end) then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, CalculateNextBuffChain(owner, {mastery.Buff.name, mastery.SubBuff.name, mastery.ThirdBuff.name}), 1, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	return unpack(actions);
end
-- 영광스러운 전사
---@param mastery class_Mastery
---@param eventArg unitKilledEventArg
function Mastery_GloriousWarrior_UnitKilled(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit) then
		return;
	end
	local actions = {};
	local allies = GetTeamUnits(owner, GetTeam(owner), false, false);
	for _, u in ipairs(allies) do
		if HasBuff(u, mastery.Buff.name) then
			AddSPPropertyActionsObject(actions, u, mastery.ApplyAmount, true, ds, true);
			InsertBuffActions(actions, owner, u, mastery.SubBuff.name, 1, true);
		end
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	return unpack(actions);
end
-- 나는 저항한다
function Mastery_IResist_UnitKilled(eventArg, mastery, owner, ds)
	if SafeIndex(eventArg, 'DamageInfo', 'Flag', 'ResistanceShoot') == nil then
		return;
	end
	
	local ability = eventArg.DamageInfo.damage_invoker;
	
	local actions = {};
	AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount, ds, 'Friendly', nil, nil, ability);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	return unpack(actions);
end
-- 용문신 가죽 운동화
function Mastery_Sneakers_DragonMark_Legend_UnitKilled(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit) 
		or not (SafeIndex(eventArg.TargetInfo.DamageFlag, 'ReactionAbility') or SafeIndex(eventArg.TargetInfo.DamageFlag, 'Counter')) then
		return;
	end
	
	local actions = {};
	AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	return unpack(actions);
end
-- 활로개척
function Mastery_ImproveWayOut_UnitKilled(eventArg, mastery, owner, ds)
	local actions = {};
	local killUnitPos = GetPosition(eventArg.Unit);
	ForeachBestFriendWithMastery(owner, mastery.name, function(bf)
		if IsAdjacentDistance(GetPosition(bf), killUnitPos) then
			AddActionApplyActForDS(actions, owner, bf, -mastery.ApplyAmount, ds, 'Friendly');
			table.insert(actions, Result_FireWorldEvent('BestFriendMasteryActivated', {Unit = owner, Target = bf, Mastery = mastery.name}, nil, true));
		end
	end)
	if #actions == 0 then
		return;
	end
	BestFriendMasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	return unpack(actions);
end
-- 살수의 길
function Mastery_RoadOfKiller_UnitKilled(eventArg, mastery, owner, ds)
	if eventArg.Unit.Race.name ~= 'Human' then
		return;
	end
	local actions = {};
	AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	return unpack(actions);
end
-- 무장 해제
function Mastery_Disarming_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local aniID = ds:PlayAni(objKey, 'Rage', false, -1, true);
	ds:Connect(masteryEventID, aniID, 0);
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 영혼 흡수
function Mastery_DrainSoul_UnitKilled(eventArg, mastery, owner, ds)
	-- 생명체가 아니면 리턴.
	local target = eventArg.Unit;
	if not owner.Race.Life or not target.Race.Life then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local actions = {};
	local _, reasons = AddActionCost(actions, owner, owner.MaxCost, true);
	if owner.Cost < owner.MaxCost then
		ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = owner.MaxCost - owner.Cost });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 예측불허
function Mastery_Unpredictability_UnitKilled(eventArg, mastery, owner, ds)
	local damageFlag = SafeIndex(eventArg, 'DamageInfo', 'Flag');
	if not table.exist({'Retribution', 'Devastate', 'Forestallment', 'Counter'}, function(flag) return SafeIndex(damageFlag, flag) ~= nil; end) then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	local actions = {};
	AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount3, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 프로그래머
function Mastery_Programmer_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	AddSPPropertyActionsObject(actions, owner, math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount, true, ds, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 자동 재정비
function Mastery_Module_AutoReload_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.CountChecker < 1 then
		return;
	end
	
	mastery.CountChecker = 0;
	local actions = {};
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount);
	AddActionCostForDS(actions, owner, -mastery.ApplyAmount3, true, nil, ds);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	-- 자율 행동 강화 프로그램
	local mastery_Module_AutoAction = GetMasteryMastered(GetMastery(owner), 'Module_AutoAction');
	if mastery_Module_AutoAction then
		AddActionApplyActForDS(actions, owner, owner, -mastery_Module_AutoAction.ApplyAmount2, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_Module_AutoAction, owner, 'UnitKilled_Self');
	end
	-- 향상된 자동 재정비
	local mastery_Module_EnhancedAutoReload = GetMasteryMastered(GetMastery(owner), 'Module_EnhancedAutoReload');
	if mastery_Module_EnhancedAutoReload and owner.HP < owner.MaxHP then
		MasteryActivatedHelper(ds, mastery_Module_EnhancedAutoReload, owner, 'UnitKilled_Self');
		local addHP = math.floor(owner.MaxHP * mastery_Module_EnhancedAutoReload.ApplyAmount / 100);
		AddActionRestoreHPForDS(actions, owner, owner, addHP, ds);
		AddMasteryDamageChat(ds, owner, mastery_Module_EnhancedAutoReload, -1 * addHP);
	end
	return unpack(actions);
end
-- 특성 : 희열
function Mastery_Catharsis_UnitKilled(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner 
		or eventArg.Unit == owner
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local look = ds:LookPos(objKey, GetPosition(eventArg.Unit));
	local aniID = ds:PlayAni(objKey, 'Catharsis', false, -1, true);

	ds:Connect(aniID, look, -1);
	ds:Connect(masteryEventID, aniID, 0);
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount);
	
	-- 검은 마녀
	local mastery_BlackWitch = GetMasteryMastered(GetMastery(owner), 'BlackWitch');
	if mastery_BlackWitch then
		MasteryActivatedHelper(ds, mastery_BlackWitch, owner, 'UnitKilled');
		AddActionApplyActForDS(actions, owner, owner, -mastery_BlackWitch.ApplyAmount, ds, 'Friendly');
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 일찍 나는 새
function Mastery_EarlyBird_UnitKilled(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local tmGrade = eventArg.Unit.TroublemakerGradeMap[GetTeam(owner)];
	if tmGrade == nil or tmGrade < 7 then
		return;
	end
	
	local actions = {};
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount3);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 나는 전설이다
function Mastery_ImLegend_UnitKilled(eventArg, mastery, owner, ds)
	if not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'CloseCheckFire') then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	local actions = {};
	AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount, ds, 'Friendly');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 내 꿈은 히어로
function Mastery_MyDreamIsHero_UnitKilled(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or not HasBuff(owner, mastery.Buff.name)
		or eventArg.Unit.Affiliation.Type ~= 'Crime'
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	if RandomTest(100 - mastery.ApplyAmount) then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
	return Mastery_MyDreamIsHero_ActivatePositiveEffect(mastery, owner, ds);
end
-- 기회 창출
function Mastery_OpportunityCreation_UnitKilled(eventArg, mastery, owner, ds)
	local dead = eventArg.Unit;
	
	local mastery_BattleOwner = GetMasteryMastered(GetMastery(owner), 'BattleOwner');
	local enemyApplied = false;
	local actions = {};
	for _, o in ipairs(GetNearObject(dead, mastery.ApplyAmount)) do	-- 1칸이 8칸이라고 해서..
		local applyAct = nil;
		if IsTeamOrAlly(owner, o) then
			applyAct = -mastery.ApplyAmount2;
		elseif IsEnemy(owner, o) and mastery_BattleOwner then
			applyAct = mastery_BattleOwner.ApplyAmount2;
			enemyApplied = true;
		end
		
		if applyAct then
			local added, reasons = AddActionApplyAct(actions, owner, o, applyAct, 'Friendly');
			if added then
				ds:UpdateBattleEvent(GetObjKey(o), 'AddWait', { Time = applyAct, Delay = true });
			end
			ReasonToUpdateBattleEventMulti(o, ds, reasons);
		end
	end
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	if enemyApplied then
		MasteryActivatedHelper(ds, mastery_BattleOwner, owner, 'UnitKilled_Self');
	end
	return unpack(actions);
end
-- 명군사
function Mastery_GreatMilitaryAffair_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, GetMasteryMastered(GetMastery(owner), 'Ambush'), owner, 'UnitKilled_Self');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	local actions = {};
	AddActionRestoreActions(actions, owner);
	mastery.CountChecker = 0;
	return unpack(actions);
end
-- 연계된 화공, 연계된 뇌공
function Mastery_ChainConfusionTactics_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	MasteryActivatedHelper(ds, GetMasteryMastered(GetMastery(owner), 'Ambush'), owner, 'UnitKilled_Self');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	local actions = {};
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount2);
	mastery.CountChecker = 0;
	return unpack(actions);
end
-- 달빛 사냥꾼
function Mastery_MoonHunter_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	if not IsDarkTime(GetMission(owner).MissionTime.name) then
		return;
	end
	
	MasteryActivatedHelper(ds, GetMasteryMastered(GetMastery(owner), 'Ambush'), owner, 'UnitKilled_Self');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	local actions = {};
	AddActionRestoreActions(actions, owner);
	mastery.DuplicateApplyChecker = 0;
	return unpack(actions);
end
-- 정의를 위한 승리의 검
function Mastery_VictorySword_UnitKilled(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or eventArg.Unit.Affiliation.Type ~= 'Crime'
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	af:AddCost(owner, mastery.ApplyAmount2, true);
	af:AddSP(owner, mastery.ApplyAmount2, true);
	
	local debuffs = GetBuffType(owner, 'Debuff');
	if #debuffs > 0 then
		local picker = RandomPicker.new(false);
		picker:addChoiceMulti(1, debuffs);
		for i = 1, mastery.ApplyAmount do
			af:RemoveBuff(owner, owner, picker:pick());
		end
	end
	mastery.DuplicateApplyChecker = 1;
	return af:UnpackActions('UnitKilled_Self');
end
-- 난 이미 알고있다.
function Mastery_AlreadyIknow_UnitKilled(eventArg, mastery, owner, ds)
	if not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'ReactionAbility') then
		return;
	end
	if eventArg.DamageInfo.damage_type ~= 'Ability' then
		return;
	end
	local ability = eventArg.DamageInfo.damage_invoker;
	if not ability or ability.HitRateType == 'Melee' then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount2, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -1 * mastery.ApplyAmount2, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self', false);
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 처형인
function Mastery_Executioner_UnitKilled(eventArg, mastery, owner, ds)
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount2, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -1 * mastery.ApplyAmount2, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self', false);
	return unpack(actions);
end
-- 일기당천
function Mastery_MatchlessWarrior_UnitKilled(eventArg, mastery, owner, ds)
	if not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'Counter') 
		and not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'Forestallment') then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount2, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -1 * mastery.ApplyAmount2, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self', false);
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 제압
function Mastery_Overpower_UnitKilled(eventArg, mastery, owner, ds)
	if not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'Forestallment') then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount2, true, ds, true);

	-- 제압의 기선제압 활성화 기능이 발동했다고 혼란을 줄 수 있으므로, 일단 여기서는 표시를 하지 말자.
--	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self', false);
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 정절의 기백
function Mastery_OverchargeSpirit_UnitKilled(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit) then
		return;
	end
	if owner.Overcharge <= 0 then
		return;
	end
	mastery.CountChecker = 	mastery.CountChecker + 1;
end
-- 정절의 기백
function Mastery_OverchargeSpirit_OverchargeEnded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if mastery.CountChecker <= 0 then
		return;
	end
	local actions = {};
	local addSP = mastery.CountChecker;
	MasteryActivatedHelper(ds, mastery, owner, 'OverchargeEnded');
	AddSPPropertyActions(actions, owner, owner.ESP.name, addSP, true, ds, true);
	mastery.CountChecker = 0;
	return unpack(actions);
end
-- 마력 회수
function Mastery_SpellPowerReturn_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' or not IsGetAbilitySubType(eventArg.Ability, 'ESP') then
		return;
	end
	local spellPower = GetBuff(owner, mastery.Buff.name);
	if spellPower == nil then
		return;
	end
	local hasAnyMeleeEnemy = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and IsMeleeDistanceAbility(owner, targetInfo.Target);
	end);
	if not hasbit(spellPower.DuplicateApplyChecker, bit(2)) then
		spellPower.DuplicateApplyChecker = spellPower.DuplicateApplyChecker + bit(2);
	end
	local actions = {};
	local mastery_SpellConverter = GetMasteryMastered(GetMastery(owner), 'SpellConverter');
	if mastery_SpellConverter and hasAnyMeleeEnemy and spellPower.Lv >= 2 then
		local addHP = owner.MaxHP * math.floor(spellPower.Lv / 2) * mastery_SpellConverter.ApplyAmount2/100;
		local reasons = {};
		addHP, reasons = AddActionRestoreHP(actions, owner, owner, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		MasteryActivatedHelper(ds, mastery_SpellConverter, owner, 'AbilityUsed_Self');
		DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false); 
	end
	return unpack(actions);
end
-------------------------------------------------------------------------------------------
-- 프로퍼티 갱신됨 [UnitPropertyUpdated]
-------------------------------------------------------------------------------------------
-- 해방자
---@param eventArg unitPropertyUpdatedEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds any
function Mastery_MadnessLiberator_UnitPropertyUpdated(eventArg, mastery, owner, ds)
	if eventArg.PropertyName ~= 'Overcharge'
		or tonumber(eventArg.Value) <= 0
		or tonumber(eventArg.PrevValue) ~= 0 then
		return;
	end
	local buffs = GetBuffType(owner, nil, nil, mastery.BuffGroup.name, true);
	if #buffs == 0 then
		return;
	end

	local actions = {};
	for _, b in ipairs(buffs) do
		InsertBuffActions(actions, owner, owner, b.name, -b.Lv, true);
	end
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitPropertyUpdated_Self');
	return unpack(actions);
end
-- 심해 탈출
function Mastery_DeepseaEscape_UnitPropertyUpdated(eventArg, mastery, owner, ds)
	if eventArg.PropertyName ~= 'Act'
		or HasBuff(owner, mastery.Buff.name) then
		return;
	end
	local applyAmount = mastery.ApplyAmount;
	-- 더는 기다릴 수 없어.
	local mastery_ICanNotWait = GetMasteryMastered(GetMastery(owner), 'ICanNotWait');
	if mastery_ICanNotWait then
		applyAmount = mastery_ICanNotWait.ApplyAmount;
	end
	if tonumber(eventArg.Value) < applyAmount then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitPropertyUpdated_Self', true);
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	-- 더는 기다릴 수 없어.
	if mastery_ICanNotWait then
		MasteryActivatedHelper(ds, mastery_ICanNotWait, owner, 'UnitPropertyUpdated_Self', true);
		if owner.Overcharge > 0 then
			table.insert(actions, Result_PropertyUpdated('Overcharge', owner.OverchargeDuration, owner, false, true));
		else
			AddSPPropertyActions(actions, owner, owner.ESP.name, owner.MaxSP - owner.SP, true, ds, true);
		end
	end
	SubscribeWorldEvent(owner, 'UnitTurnStart_Self', function(eventArg, ds, subscriptionID)
		UnsubscribeWorldEvent(owner, subscriptionID);
		local actions = {};
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
		return unpack(actions);
	end);
	return unpack(actions);
end
-- 호환성 증가 - 지연 복구
function Mastery_MachineUnique_Waiting_UnitPropertyUpdated(eventArg, mastery, owner, ds)
	if eventArg.PropertyName ~= 'Act'
		or tonumber(eventArg.Value) < mastery.ApplyAmount then
		return;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitPropertyUpdated_Self', true);
	return Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true);
end
-- 빗나간 죽음
function Mastery_LuckyCheatDeath_UnitPropertyUpdated(eventArg, mastery, owner, ds)
	if eventArg.PropertyName ~= 'Overcharge' then
		return;
	end
	local curValue = tonumber(eventArg.Value);
	local prevValue = GetInstantProperty(owner, 'PrevOvercharge') or 0;
	SetInstantProperty(owner, 'PrevOvercharge', curValue);
	if curValue <= 0 or curValue <= prevValue then
		return;
	end
	local adjustValue = GetInstantProperty(owner, mastery.name) or 0;
	adjustValue = adjustValue + mastery.ApplyAmount2;
	SetInstantProperty(owner, mastery.name, adjustValue);
end
-- 환희
function Mastery_Rapture_UnitPropertyUpdated(eventArg, mastery, owner, ds)
	if eventArg.PropertyName ~= 'Overcharge' then
		return;
	end
	local curValue = tonumber(eventArg.Value);
	local prevValue = tonumber(eventArg.PrevValue);
	if curValue <= 0 or curValue <= prevValue then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitPropertyUpdated_Self', true);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 모든 일에는 운이 따라야 한다.
function Mastery_AllFollowingLuck_UnitPropertyUpdated(eventArg, mastery, owner, ds)
	if not IsUnprotectedExposureState(owner, GetPosition(owner), true)
		or eventArg.PropertyName ~= 'Overcharge' then
		return;
	end
	local curValue = tonumber(eventArg.Value);
	local prevValue = tonumber(eventArg.PrevValue);
	if curValue <= 0 or curValue <= prevValue then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitPropertyUpdated_Self', true);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 과충전 부스터
function Mastery_Module_OverchargeAdditionalBooster_UnitPropertyUpdated(eventArg, mastery, owner, ds)
	if eventArg.PropertyName ~= 'Overcharge' then
		return;
	end
	local curValue = tonumber(eventArg.Value);
	local prevValue = tonumber(eventArg.PrevValue);
	if curValue <= 0 or curValue <= prevValue then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitPropertyUpdated_Self', true);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
----------------------------------- End of EventHandler ------------------------------------
-- DB에는 존재하지 않을 수 있으나 무조건 기본으로 들고 들어갈 마스터리 설정
function GetBaseMastery_PC(obj) -- Pc.Object
	local list = SetBasicMasteries(obj, true);
	-- 1. 회사 선택 특성.
	local company = GetCompany(obj);
	local roster = GetRosterFromObject(obj)
	if company == nil then
		company = GetSnapshotCompany(obj);
	end
	if company == nil then
		LogAndPrint('GetBaseMastery_PC', 'ERROR! No company');
		Traceback();
	else
		local companyMastery = nil;
		if company.CompanyMastery ~= 'None' then
			local curCompnayMastery = company.CompanyMasteries[company.CompanyMastery];
			if curCompnayMastery.Opened then
				companyMastery = company.CompanyMastery;
			end
		end
		if roster and roster.RosterType == 'Pc' and roster.Affiliation ~= 'None' then
			local organizationCls = GetClassList('Organization')[roster.Affiliation];
			if organizationCls then
				companyMastery = organizationCls.BasicMastery;
			end
		end
		if companyMastery then
			list[companyMastery] = 1;
		end
	end
	-- 2. 개인 선택 특성.
	if roster and roster.BasicMastery ~= 'None' then
		list[roster.BasicMastery] = 1;
	end
	if roster and roster.RosterType == 'Pc' then
		local fixedMastery = GetWithoutError(roster, 'FixedMastery');
		if fixedMastery then
			for i = 1, #fixedMastery do
				local fixedMasteryName = fixedMastery[i];
				list[fixedMasteryName] = 1;
			end
		end
	end
	if roster and roster.RosterType == 'Beast' then
		local fixedMastery = GetWithoutError(roster.BeastType, 'FixedMastery');
		if fixedMastery then
			for i = 1, #fixedMastery do
				local fixedMasteryName = fixedMastery[i];
				list[fixedMasteryName] = 1;
			end
		end
		for i = 1, roster.BeastType.EvolutionMaxStage do
			local evolutionMastery = GetWithoutError(roster, string.format('EvolutionMastery%d', i));
			if evolutionMastery and evolutionMastery ~= 'None' then
				list[evolutionMastery] = i;
			end
		end
	end
	if roster and roster.RosterType == 'Machine' then
		if roster.OSType ~= 'None' then
			list[roster.OSType] = 1;
		end
		if roster.CraftMastery ~= 'None' then
			list[roster.CraftMastery] = 1;
		end
		for i = 1, 3 do
			local upgradeMastery = GetWithoutError(roster, string.format('AIUpgradeMastery%d', i));
			if upgradeMastery and upgradeMastery ~= 'None' then
				list[upgradeMastery] = i + 1;
			end
		end
	end
	-- 2.2. 추가 직업 특성
	local extraJobMasteries = GetExtraJobMasteries(obj, function(masteryName)
		local masteryLv = list[masteryName];
		return masteryLv and masteryLv > 0;
	end);
	for _, extraJobMastery in pairs(extraJobMasteries) do
		list[extraJobMastery] = 1;
	end
	-- 3. 스토리 모드 특성.
	if company and roster and roster.RosterType == 'Pc' then
		local difficultyCls = GetClassList('GameDifficulty')[company.GameDifficulty];
		local difficultyMastery = SafeIndex(difficultyCls, 'Mastery', 'name');
		if difficultyMastery and difficultyMastery ~= 'None' then
			list[difficultyMastery] = 1;
		end
	end
	return list;
end
-------------------------------------------------------------------------------
-- 필드 이펙트 추가 [FieldEffectAdded]
-------------------------------------------------------------------------------
-- 초고속 그물 연결망
function Mastery_FastWebNetwork_FieldEffectAdded(eventArg, mastery, owner, ds)
	if eventArg.FieldEffectType ~= 'Web' or eventArg.Giver ~= owner then
		return;
	end

	local actions = {};
	AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount * #eventArg.PositionList, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'FieldEffectAdded');
	return unpack(actions);
end
function Mastery_FlammableObject_FieldEffectAdded(eventArg, mastery, owner, ds)
	local fieldCls = GetClassList('FieldEffect')[eventArg.FieldEffectType];
	for _, affector in ipairs(fieldCls.BuffAffector) do
		if affector.ApplyBuff.name ~= 'Burn' then
			return;
		end
	end
	
	if not PositionInRange( eventArg.PositionList, GetPosition(owner)) then
		return;
	end
	
	return Result_Damage(owner.HP, 'Normal', 'Hit', owner, owner, 'Ability', 'Fire', mastery);
end
function Mastery_ShockableObject_FieldEffectAdded(eventArg, mastery, owner, ds)
	local fieldCls = GetClassList('FieldEffect')[eventArg.FieldEffectType];
	for _, affector in ipairs(fieldCls.BuffAffector) do
		if affector.ApplyBuff.name ~= 'ElectricShock' then
			return;
		end
	end
	
	if not PositionInRange( eventArg.PositionList, GetPosition(owner)) then
		return;
	end
	
	return Result_Damage(owner.HP, 'Normal', 'Hit', owner, owner, 'Ability', 'Lightning', mastery);
end
function Mastery_WebTailor_FieldEffectAdded(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner then
		return;
	end
	local isTargetFieldEffect = false;
	local fieldCls = GetClassList('FieldEffect')[eventArg.FieldEffectType];
	for _, affector in ipairs(fieldCls.BuffAffector) do
		if affector.ApplyBuff.name == mastery.Buff.name then
			isTargetFieldEffect = true;
			break;
		end
	end	
	if not isTargetFieldEffect then
		return;
	end
	local fieldEffectCount = #eventArg.PositionList;
	-- 이동 중엔 카운팅만 한다.
	if mastery.DuplicateApplyChecker > 0 then
		local prevCount = GetInstantProperty(owner, mastery.name) or 0;
		local newCount = prevCount + fieldEffectCount;
		SetInstantProperty(owner, mastery.name, newCount);
		return;
	end
	local stepCount = math.floor(fieldEffectCount / mastery.ApplyAmount);	-- ApplyAmount 당
	if stepCount <= 0 then
		return;
	end
	local applyAct = -1 * stepCount * mastery.ApplyAmount2;			-- ApplyAmount2 만큼 감소
	
	local actions = {};
	local ownerKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'FieldEffectAdded');
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 업화
function Mastery_Hellfire_FieldEffectAdded(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner
		or eventArg.FieldEffectType ~= 'Fire'
		or SafeIndex(eventArg.ActionInfo, 'invoke_type') ~= 'Ability'
		or owner.CostType.name ~= 'Vigor' then
		return;
	end
	local fieldEffectCount = #eventArg.PositionList;
	if fieldEffectCount == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'FieldEffectAdded');
	AddActionCostForDS(actions, owner, fieldEffectCount, true, nil, ds);
	return unpack(actions);
end
-------------------------------------------------------------------------------
-- 유닛 위치 변화 [UnitPositionChanged]
-------------------------------------------------------------------------------
-- 무리쫓기
function Mastery_GroupFollowing_UnitPositionChanged(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner
		or GetTeam(eventArg.Unit) ~= GetTeam(owner) then
		return;
	end

	if not IsInSight(owner, eventArg.BeginPosition, true) or IsInSight(owner, eventArg.Position, true) then
		return;
	end

	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitMoved');
	local applyAmount = mastery.ApplyAmount;
	-- 무리 이동
	local mastery_GroupingMoving = GetMasteryMastered(GetMastery(owner), 'GroupingMoving');
	if mastery_GroupingMoving then
		MasteryActivatedHelper(ds, mastery_GroupingMoving, owner, 'UnitMoved');
		applyAmount = applyAmount + mastery_GroupingMoving.ApplyAmount;
	end
	AddActionApplyActForDS(actions, owner, owner, -applyAmount, ds, 'Friendly');
	return unpack(actions);
end
-- 기선 제압
function Mastery_Forestallment_LimitTest(mastery, owner)
	local limit = 1;
	-- 회색의 저격수
	local mastery_GreySniper = GetMasteryMastered(GetMastery(owner), 'GreySniper');
	if mastery_GreySniper then
		limit = limit + mastery_GreySniper.ApplyAmount3;
	end
	return mastery.CountChecker < limit;
end
function Mastery_Forestallment_UnitPositionChanged(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0 
		or not Mastery_Forestallment_LimitTest(mastery, owner)
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or owner.IsMovingNow > 0
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not IsMeleeDistance(GetPosition(owner), eventArg.Position)
		or GetBuffStatus(owner, 'Unconscious', 'Or')
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or eventArg.Blink 
		or eventArg.NoEvent then
		return;
	end
	local mission = GetMission(owner);
	local alreadyObj = GetObjectByPosition(mission, eventArg.Position);
	if alreadyObj ~= nil and alreadyObj ~= eventArg.Unit then
		-- 이 위치에 이미 누군가 있어!
		return;
	end
	
	local overwatch = FindAbility(owner, owner.OverwatchAbility_Melee);
	if overwatch == nil or overwatch.HitRateType ~= 'Melee' or not IsAvailableAbility(owner, overwatch) then
		return;
	end
	local rangeClsList = GetClassList('Range');
	local range = CalculateRange(owner, overwatch.TargetRange, GetPosition(owner));
	local p = eventArg.Position;
	if PositionInRange(range, p) then
		local targetKey = GetObjKey(eventArg.Unit);
		local eventCmd = ds:SubscribeFSMEvent(targetKey, 'StepForward', 'CheckUnitArrivePosition', {CheckPos=p}, true, true);
		if eventArg.MoveID and ds:GetRefID(eventArg.MoveID) ~= eventArg.MoveID then
			ds:Connect(eventCmd, eventArg.MoveID, 0);		-- 루프를 만들어서 교체를 시키려고
			ds:Connect(eventArg.MoveID, eventCmd, 0);
		else
			ds:SetConditional(eventCmd);
		end
		
		local chatID = ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitMovedSingleStep'});
		ds:Connect(chatID, eventCmd, -1);
		local hitCount = eventArg.OverwatchHitCount or 0;
		local battleEvents = {{Object = owner, EventType = mastery.name}};
		local targetPos = GetPosition(eventArg.Unit);
		local resultModifier = {ReactionAbility=true, Forestallment=true, Moving=true, BattleEvents = battleEvents};
		-- 선의 선
		local mastery_AcuityForestallment = GetMasteryMastered(GetMastery(owner), 'AcuityForestallment');
		if mastery_AcuityForestallment then
			resultModifier['Inevitable'] = true;
			resultModifier['CriticalHit'] = true;
		end
		local abilityAction = Result_UseAbilityTarget(owner, overwatch.name, eventArg.Unit, resultModifier, true, {NoCamera = true, Preemptive=true, PreemptiveOrder = hitCount});
		mastery.CountChecker = mastery.CountChecker + 1;
		abilityAction.on_fail_actions = {Result_DirectingScript(function(mid, ds, args)
			mastery.CountChecker = mastery.CountChecker - 1;
		end)};
		abilityAction.nonsequential = true;
		abilityAction.free_action = true;
		abilityAction._ref = eventCmd;
		abilityAction._ref_offset = -1;
		abilityAction.final_useable_checker = function()
			return GetBuffStatus(owner, 'Attackable', 'And')
				and PositionInRange(CalculateRange(owner, overwatch.TargetRange, GetPosition(owner)), eventArg.Position);
		end;
		eventArg.OverwatchHitCount = hitCount + 1;
		return abilityAction;
	end
end
-- 자동 제압 사격
function Mastery_Module_ForestallmentFire_UnitPositionChanged(eventArg, mastery, owner, ds)
	local applyDist = mastery.ApplyAmount;
	if applyDist == 1 then
		applyDist = 1.4;
	end
	if eventArg.Unit.HP <= 0 
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or mastery.DuplicateApplyChecker > 0
		or owner.IsMovingNow > 0
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= (applyDist + 0.4)
		or GetBuffStatus(owner, 'Unconscious', 'Or')
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or eventArg.Blink then
		return;
	end
	local limit = mastery.ApplyAmount4;
	-- 향상된 자동 제압 사격
	local mastery_Module_EnhancedForestallmentFire = GetMasteryMastered(GetMastery(owner), 'Module_EnhancedForestallmentFire');
	if mastery_Module_EnhancedForestallmentFire then
		limit = limit + mastery_Module_EnhancedForestallmentFire.ApplyAmount;
	end
	if mastery.CountChecker >= limit then
		return;
	end
	return Mastery_Module_ForestallmentFire_TestMoveStep(eventArg, mastery, owner, ds);
end
-- 근접 제압 사격
function Mastery_CloseCheckFire_UnitPositionChanged(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= (mastery.ApplyAmount + 0.4)
		or GetBuffStatus(owner, 'Unconscious', 'Or')
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or eventArg.Blink then
		return;
	end
	return Mastery_CloseCheckFire_TestMoveStep(eventArg, mastery, owner, ds);
end
-- 자동 반응 사격
function Mastery_Module_CloseCheckFire_UnitPositionChanged(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= (mastery.ApplyAmount + 0.4)
		or GetBuffStatus(owner, 'Unconscious', 'Or')
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or eventArg.Blink then
		return;
	end
	return Mastery_Module_CloseCheckFire_TestMoveStep(eventArg, mastery, owner, ds);
end
-- 살금 살금/슬금 슬금
function Mastery_StealthyFootsteps_UnitPositionChanged(eventArg, mastery, owner, ds)
	local satisfied = false;
	if eventArg.Blink then
		satisfied = true;
	end
	-- 잠행술의 대가, 수풀 속의 그림자
	local mastery_Stealthwalker = GetMasteryMasteredList(GetMastery(owner), {'Stealthwalker', 'BushStealthWalker'});
	if mastery_Stealthwalker and HasBuff(owner, mastery_Stealthwalker.Buff.name) then
		satisfied = true;
	end
	if satisfied then
		mastery.CountChecker = 1;
	else
		mastery.CountChecker = 0;
	end
	mastery.DuplicateApplyChecker = 0;
end
-------------------------------------------------------------------------------
-- 기타 이벤트
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--- 해킹
function Mastery_SurveillanceNetworking_HackingOccured(eventArg, mastery, owner, ds)
	local command = eventArg.Success and 'Converted' or 'Alert';
	
	local actions = {Result_FireWorldEvent('WatchtowerControl', {Commander = owner, Command = command, Hacker = eventArg.Hacker})};
	if eventArg.Success then
		table.insert(actions, Result_ChangeTeam(owner, GetTeam(eventArg.Hacker)));
	else
		local hackerKey = GetObjKey(eventArg.Hacker);
		ds:UpdateBattleEvent(hackerKey, 'GetWord', { Color = 'Red', Word = 'Detected' });
		ds:AlertScreenEffect(hackerKey);
	end
	return unpack(actions);
end
-- 격앙
function Mastery_Excitement_ActionPointRestored(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	local actions = {}
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	MasteryActivatedHelper(ds, mastery, owner, 'ActionPointRestored', nil);
	return unpack(actions);
end
---------------------------------------------------------------------------------
-- [ActionCostAdded]
---------------------------------------------------------------------------------
-- 연료 제어
function Mastery_Application_FuelControl_ActionCostAdded(eventArg, mastery, owner, ds)
	if eventArg.AddAmount >= 0 then
		return;
	end
	
	local actions = {};
	local restoreAct = mastery.ApplyAmount2 * math.floor(-eventArg.AddAmount / mastery.ApplyAmount);
	if restoreAct > 0 then
		AddActionApplyActForDS(actions, owner, owner, -restoreAct, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery, owner, 'ActionCostAdded');
	end
	return unpack(actions);
end
-- 독립형 OS
function Mastery_MacOS_ActionCostAdded(eventArg, mastery, owner, ds)
	if eventArg.AddAmount <= 0 then
		return;
	end
	
	local actions = {};
	local restoreAct = math.min(mastery.ApplyAmount, eventArg.AddAmount);
	if restoreAct > 0 then
		AddActionApplyActForDS(actions, owner, owner, -restoreAct, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery, owner, 'ActionCostAdded');
	end
	return unpack(actions);
end
-- 자폭
function Mastery_Module_Suicide_ActionCostAdded(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker > 0
		or owner.Cost > 0 then
		return;
	end
	
	mastery.DuplicateApplyChecker = 1;
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	return unpack(actions);
end
function Mastery_Fuel_ActionCostAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.AddAmount == 0 then
		return;
	end
	
	local actions = {};
	local buff = GetBuff(owner, mastery.Buff.name)
	
	if owner.Cost == 0 and buff == nil then
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	elseif owner.Cost > 0 and buff ~= nil then
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, -1 * buff.Lv);
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- [ChainEffectOccured]
--------------------------------------------------------------------------------
-- 사냥꾼과 사냥개
function Mastery_HunterAndHuntingDog_ChainEffectOccured(eventArg, mastery, owner, ds)
	-- 어빌리티 사용 중에만 발동
	if mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	if GetInstantProperty(eventArg.Trigger, 'SummonMaster') ~= GetObjKey(owner) then
		return;
	end
	if mastery.CountChecker > 0 then
		return;
	end	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'ChainEffectOccured');
	AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	mastery.CountChecker = 1;
	return unpack(actions);
end
-- 연환계
function Mastery_ChainTactics_ChainEffectOccured(eventArg, mastery, owner, ds)
	-- 어빌리티 사용 중에만 발동
	if mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	local trigger = eventArg.Trigger;
	if GetMasteryMastered(GetMastery(trigger), 'TrapSystem') then
		trigger = GetExpTaker(trigger);
	end
	if trigger ~= owner then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'ChainEffectOccured');
	
	local hasteAmount = mastery.ApplyAmount;	
	local mastery_GreatMilitaryAffairs = GetMasteryMastered(GetMastery(owner), 'GreatMilitaryAffairs');
	if mastery_GreatMilitaryAffairs then
		hasteAmount = hasteAmount + mastery_GreatMilitaryAffairs.ApplyAmount;
		MasteryActivatedHelper(ds, mastery_GreatMilitaryAffairs, owner, 'ChainEffectOccured');
	end
	
	-- 설계된 함정
	local mastery_TrapDesign = GetMasteryMastered(GetMastery(owner), 'TrapDesign');
	if mastery_TrapDesign then
		MasteryActivatedHelper(ds, mastery_TrapDesign, owner, 'ChainEffectOccured');
	end
	
	for _, obj in ipairs(GetNearObject(owner, mastery.ApplyAmount2 + 0.4)) do
		if IsTeamOrAlly(owner, obj) then
			AddActionApplyActForDS(actions, owner, obj, -hasteAmount, ds, 'Friendly');
		end
	end
	if mastery_TrapDesign then
		for _, obj in ipairs(GetNearObject(eventArg.Unit, mastery_TrapDesign.ApplyAmount + 0.4)) do
			if IsEnemy(owner, obj) then
				AddActionApplyActForDS(actions, owner, obj, mastery_TrapDesign.ApplyAmount2, ds, 'Hostile', nil, nil, eventArg.Ability);
			end
		end
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- [HackingSucceeded]
--------------------------------------------------------------------------------
function Mastery_Genius_HackingSucceeded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local abilityName = SafeIndex(eventArg, 'Ability', 'name');
	if abilityName ~= 'HackingProtocol' then
		return;
	end
	-- 사용 횟수 제한이 있는 모든 프로토콜 어빌리티 (UseCount가 MaxUseCount 이상이면 무시)
	local abilityList = GetAllAbility(owner);
	abilityList = table.filter(abilityList, function(ability)
		return IsProtocolAbility(ability) and ability.IsUseCount and ability.AutoUseCount and ability.UseCount < ability.MaxUseCount;
	end);
	if #abilityList == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'HackingSucceeded');
	-- 사용 횟수 제한이 있는 모든 프로토콜 어빌리티 UseCount 증가 (MaxUseCount를 넘기지는 않음)
	for _, ability in ipairs(abilityList) do
		AddAbilityUseCountActions(actions, owner, ability, mastery.ApplyAmount2, true);
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- [HackingFailed]
--------------------------------------------------------------------------------
-- 시스템 더미 프로그램
function Mastery_Module_SystemDummyProgram_HackingFailed(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'HackingFailed');
	table.insert(actions, Result_TurnEnd(eventArg.Unit, false));
	-- 턴 종료 액션이 처리되어서, 턴 상태가 변경되어야 제대로 처리되므로 지연 처리
	local target = eventArg.Unit;
	table.insert(actions, Result_DirectingScript(function(mid, ds, arg)
		local actions = {};
		AddActionApplyActForDS(actions, owner, target, mastery.ApplyAmount, ds, 'Hostile');
		return unpack(actions);
	end, nil, true, false));
	-- 다중 보안 시스템
	local mastery_Module_MultiSystemSecurity = GetMasteryMastered(GetMastery(owner), 'Module_MultiSystemSecurity');
	if mastery_Module_MultiSystemSecurity then
		MasteryActivatedHelper(ds, mastery_Module_MultiSystemSecurity, owner, 'HackingFailed');
		table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
		if not owner.TurnState.TurnEnded then
			table.append(actions, {GetInitializeTurnActions(owner)});
		end
	end
	return unpack(actions);
end
---------------------------------------------------------------------------------
-- 데미지 컨베이어
---------------------------------------------------------------------------------
-- 자비의 거미줄
function DamageConveyor_HideClimbWeb(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.CountChecker >= mastery.ApplyAmount then
		return damage;
	end

	-- 데미지로 죽을 것 같으면
	if damage < owner.HP then
		return damage;
	end

	if not test then
		mastery.CountChecker = mastery.CountChecker + 1;
		mastery.DuplicateApplyChecker = 1;
		if damageInfo.damage_type == 'Ability' then
			AddMasteryInvokedEvent(owner, mastery.name, 'FinalHit');
		end
	end
	return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
end
function DamageConveyor_FlammableObject(owner, mastery, damage, damageBase, damageInfo, test)
	if damageBase <= 0 then
		return damage;
	end
	if damageInfo.damage_sub_type == 'Ice' then
		return 0;	-- 빙결 데미지는 안들어감
	elseif damageInfo.damage_sub_type == 'Fire' or damageInfo.damage_sub_type == 'Lightning' or (damageInfo.damage_invoker and damageInfo.damage_invoker.name == 'FragGrenade') then
		return owner.HP;
	end
	return damage;
end
function DamageConveyor_Amulet_Guardian(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker >= mastery.ApplyAmount then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
			AddUnitStats(owner, 'AvoidDead', 1);
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
function DamageConveyor_Amulet_Scourge(owner, mastery, damage, damageBase, damageInfo, test)
	local scorgeAbil = FindAbility(owner, 'Potion_Scourge');
	if not scorgeAbil or mastery.CountChecker >= scorgeAbil.UseCount or HasBuff(owner, mastery.Buff.name) then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.CountChecker = mastery.CountChecker + 1;
			AddUnitStats(owner, 'AvoidDead', 1);
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
function DamageConveyor_SandCastle(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker >= mastery.ApplyAmount then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
			AddUnitStats(owner, 'AvoidDead', 1);
			if damageInfo.damage_type == 'Ability' then
				AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			end
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
function DamageConveyor_Amulet_Hunter(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker > 0 then
		return damage;
	end
	
	if damage > 0 then
		if not test then
			mastery.DuplicateApplyChecker = 1;
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	end
	
	return damage;
end
function DamageConveyor_Module_MachineFury(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker > 0 then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP and GetBuff(owner, 'Shutdown') == nil then
		if not test then
			mastery.DuplicateApplyChecker = 1;
			AddUnitStats(owner, 'AvoidDead', 1);
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			AddBattleEvent(owner, 'BuffInvokedFromAbility', {Buff = mastery.Buff.name, EventType = 'FirstHit'});
		end
		return owner.HP - 1, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
function DamageConveyor_HungryWolf(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker > 0 then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = 1;
			AddUnitStats(owner, 'AvoidDead', 1);
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			AddBattleEvent(owner, 'GetWordCustomEvent', {Word = 'HungryWolf_GetBack', EventType = 'FirstHit', Color = 'Yellow'});
			AddBattleEvent(owner, 'BuffInvokedFromAbility', {Buff = mastery.Buff.name, EventType = 'FirstHit'});
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
function DamageConveyor_FightAgainstFate(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker >= mastery.ApplyAmount then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
			SetInstantProperty(owner, mastery.name, true);
			AddUnitStats(owner, 'AvoidDead', 1);
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			AddBattleEvent(owner, 'BuffInvokedFromAbility', {Buff = mastery.Buff.name, EventType = 'FirstHit'});
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- 동족 포식
function DamageConveyor_Cannibalization(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker > 0 
		or damage <= owner.HP 
		or damageInfo.damage_type == 'System'
		or damageInfo.damage_type == 'SystemBuff'
		or GetBuffStatus(owner, 'Unconscious', 'Or') then
		return damage;
	end
	
	if not test then
		mastery.DuplicateApplyChecker = 1;
		SetInstantProperty(owner, 'Undead', true);
	end
	return owner.HP - 1, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
end
-- 아발론의 가호
function DamageConveyor_AvalonArmor(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.CountChecker > 0 then
		return damage;
	end
	if damage >= owner.HP and owner.Cost > 0 then
		if not test then
			mastery.CountChecker = 1;
		end
		if damageInfo.damage_type == 'Ability' then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- 용암 가죽
function DamageConveyor_LavaSkin(owner, mastery, damage, damageBase, damageInfo, test)
	if damageInfo.damage_type ~= 'Ability' or damageInfo.damage_sub_type ~= 'Ice' then
		return damage;
	end	
	local testHP = math.floor(owner.MaxHP * mastery.ApplyAmount2 / 100);
	if damage > 0 and damage < testHP then
		if not test then
			SetInstantProperty(owner, mastery.name, true);
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			-- 폭염의 괴수
			local mastery_HotMonster = GetMasteryMastered(GetMastery(owner), 'HotMonster');
			if mastery_HotMonster then
				mastery_HotMonster.CountChecker = 1;
			end
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- 얼음 가죽
function DamageConveyor_IceSkin(owner, mastery, damage, damageBase, damageInfo, test)
	if damageInfo.damage_type ~= 'Ability' or damageInfo.damage_sub_type ~= 'Fire' then
		return damage;
	end	
	local testHP = math.floor(owner.MaxHP * mastery.ApplyAmount2 / 100);
	if damage > 0 and damage < testHP then
		if not test then
			SetInstantProperty(owner, mastery.name, true);
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			-- 혹한의 괴수
			local mastery_ColdMonster = GetMasteryMastered(GetMastery(owner), 'ColdMonster');
			if mastery_ColdMonster then
				mastery_ColdMonster.CountChecker = 1;
			end
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- 번개 가죽
function DamageConveyor_LightningSkin(owner, mastery, damage, damageBase, damageInfo, test)
	if damageInfo.damage_type ~= 'Ability' or damageInfo.damage_sub_type ~= 'Earth' then
		return damage;
	end	
	local testHP = math.floor(owner.MaxHP * mastery.ApplyAmount2 / 100);
	if damage > 0 and damage < testHP then
		if not test then
			SetInstantProperty(owner, mastery.name, true);
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			-- 빗속의 괴수
			local mastery_RainMonster = GetMasteryMastered(GetMastery(owner), 'RainMonster');
			if mastery_RainMonster then
				mastery_RainMonster.CountChecker = 1;
			end
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- 달빛 가죽
function DamageConveyor_MoonSkin(owner, mastery, damage, damageBase, damageInfo, test)
	if damageInfo.damage_type ~= 'Ability' or damageInfo.damage_sub_type ~= 'Lightning' then
		return damage;
	end	
	local testHP = math.floor(owner.MaxHP * mastery.ApplyAmount2 / 100);
	if damage > 0 and damage < testHP then
		if not test then
			SetInstantProperty(owner, mastery.name, true);
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			-- 달빛의 괴수
			local mastery_MoonMonster = GetMasteryMastered(GetMastery(owner), 'MoonMonster');
			if mastery_MoonMonster then
				mastery_MoonMonster.CountChecker = 1;
			end
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- EMP 차폐 코팅
function DamageConveyor_Module_AntiEMP(owner, mastery, damage, damageBase, damageInfo, test)
	if damageInfo.damage_type ~= 'Ability' or damageInfo.damage_sub_type ~= 'EMP' then
		return damage;
	end	
	if damage > 0 then
		if not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- 황금 비늘
function DamageConveyor_GoldScale(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker >= mastery.ApplyAmount then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
			AddUnitStats(owner, 'AvoidDead', 1);
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- 각인된 공포
function DamageConveyor_FearForDeath(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker >= mastery.ApplyAmount then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
			SetInstantProperty(owner, mastery.name, true);
			AddUnitStats(owner, 'AvoidDead', 1);
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			AddBattleEvent(owner, 'BuffInvokedFromAbility', {Buff = mastery.Buff.name, EventType = 'FirstHit'});
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- 안개 속을 살금살금
function DamageConveyor_StealthyFootstepsInSmoke(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker >= mastery.ApplyAmount or not HasBuff(owner, mastery.Buff.name) then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
			AddUnitStats(owner, 'AvoidDead', 1);
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
--- 최후의 발악
function DamageConveyor_LastAttack(owner, mastery, damage, damageBase, damageInfo, test)
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP and damageInfo.damage_type == 'Ability' then
		if not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FinalHit');
			if GetInstantProperty(owner, mastery.name) == nil then
				SetInstantProperty(owner, mastery.name, damageInfo.damage_invoker);
			end
		end
		return owner.HP - 1, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	end
	return damage;
end
---------------------------------------------------------------------------------
-- 과충전 해제
---------------------------------------------------------------------------------
--- 재정비
function Mastery_Rearrange_OverchargeEnded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end

	local actions = {};
	
	local addSP = mastery.ApplyAmount;
	local objKey = GetObjKey(owner);
	
	-- 각성
	local masteryTable = GetMastery(owner);
	local mastery_Awakening = GetMasteryMastered(masteryTable, 'Awakening');
	if mastery_Awakening then
		addSP = addSP + mastery_Awakening.ApplyAmount2;
	end
	
	AddSPPropertyActions(actions, owner, owner.ESP.name, addSP, true, ds, true);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'OverchargeEnded'});
	
	return unpack(actions);
end
-- 불꽃의 군주
function Mastery_LordOfFlame_OverchargeEnded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 꺼지지 않는 불꽃
	local masteryTable = GetMastery(owner);
	local mastery_EternalFlame = GetMasteryMastered(masteryTable, 'EternalFlame');
	if not mastery_EternalFlame then
		return;
	end
	local actions = {};
	local addSP = mastery.ApplyAmount;
	MasteryActivatedHelper(ds, mastery, owner, 'OverchargeEnded');
	MasteryActivatedHelper(ds, mastery_EternalFlame, owner, 'OverchargeEnded');
	AddSPPropertyActions(actions, owner, owner.ESP.name, addSP, true, ds, true);
	return unpack(actions);
end
-- 열전환 최적화
function Mastery_Module_HeatConversionOptimization_OverchargeEnded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local addSP = mastery.ApplyAmount;
	if owner.Info.name == 'Drone_Rifle' then
		addSP = addSP + mastery.ApplyAmount2;
	elseif owner.Info.name == 'Drone_Flamethrower' then
		addSP = addSP + mastery.ApplyAmount3;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'OverchargeEnded');
	AddSPPropertyActions(actions, owner, owner.ESP.name, addSP, true, ds, true);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 버프 추가 [BuffAdded]
----------------------------------------------------------------------------
-- 진동 감지
function Mastery_VibrationDetection_BuffAddRemove(eventArg, mastery, owner, ds)
	if eventArg.BuffName ~= mastery.Buff.name then
		return;
	end

	return Result_InvalidateObject(owner, 'SightRange');
end
-- 반향정위
function Mastery_Echolocation_BuffAdded(eventArg, mastery, owner, ds)
	if GetBuffGiver(eventArg.Buff) ~= owner
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end

	local actions = {};
	InsertBuffActionsModifier(actions, owner, eventArg.Unit, mastery.Buff.name, 1, eventArg.Buff.Turn, true);
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	return unpack(actions);
end
-- 만년설
function Mastery_PermanentSnow_BuffAdded(eventArg, mastery, owner, ds)
	if GetBuffGiver(eventArg.Buff) ~= owner
		or not IsBuffType(eventArg.Buff, { 'Buff', 'Debuff' }, nil, mastery.BuffGroup.name) then
		return;
	end
	local addTurn = mastery.ApplyAmount;
	local mastery_LargeSnowflakes = GetMasteryMastered(GetMastery(owner), 'LargeSnowflakes');
	if mastery_LargeSnowflakes then
		addTurn = addTurn + mastery_LargeSnowflakes.ApplyAmount3;
	end
	local actions = {};
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, eventArg.Unit, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, eventArg.Unit, eventArg.Buff.name, true, true));
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	return unpack(actions);
end
-- 행운수집가
function Mastery_FortuneCollector_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.BuffName ~= mastery.Buff.name then
		return;
	end
	
	local actions = {};
	AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	return unpack(actions);
end
-- 숙면
function Mastery_DeepSleep_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	SetInstantProperty(owner, 'DeepSleep_ExpCache_'..eventArg.Buff.name, {Lv = owner.Lv, Exp = owner.Exp, JobLv = owner.JobLv, JobExp = owner.JobExp});
end
-- 함정 시스템
function Mastery_TrapSystem_BuffAdded(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker > 0 
		or not owner.Detected then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
	local ownerCamMove = ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false, false, 0.5);
	local detectMessage = ds:UpdateBattleEvent(GetObjKey(owner), 'GetWordAliveOnly', { Color = 'Red', Word = 'Detected' });
	ds:Connect(detectMessage, ownerCamMove, 0.25);
end
-- 나의 꿈은 히어로
function Mastery_MyDreamIsHero_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.BuffName ~= mastery.Buff.name then
		return;
	end
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	local buff = goodBuffPicker:PickBuff();
	if buff == nil then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff, 1);
	return unpack(actions);
end
-- 꼭꼭 숨어라
function Mastery_HideHide_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.BuffName ~= 'Conceal' and eventArg.BuffName ~= 'Conceal_For_Aura' then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', {Time = -mastery.ApplyAmount, Delay = true});
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	
	return unpack(actions);
end
-- 행운의 여신
function Mastery_GoddessOfFortune_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.BuffName ~= mastery.Buff.name then
		return;
	end
	
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	local buff = goodBuffPicker:PickBuff();
	if buff == nil then
		return;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff, 1);
	return unpack(actions);
end
-- 기만
function Mastery_Subterfuge_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if eventArg.Buff.Type ~= 'Buff' and eventArg.Buff.Type ~= 'Debuff' then
		return;
	end
	if eventArg.Buff.SubType ~= 'Physical' and eventArg.Buff.SubType ~= 'Mental' then
		return;
	end
	-- 1턴 이하의 디버프에는 적용되지 않음
	if eventArg.Buff.Type == 'Debuff' and eventArg.Buff.Turn <= 1 then
		return;
	end
	local addTurn = mastery.ApplyAmount;
	if eventArg.Buff.Type == 'Debuff' then
		addTurn = -1 * mastery.ApplyAmount2;
	end
	-- 잠행술의 대가
	local mastery_Stealthwalker = GetMasteryMastered(GetMastery(owner), 'Stealthwalker');
	if mastery_Stealthwalker and eventArg.Buff.name == mastery_Stealthwalker.Buff.name then
		addTurn = addTurn + mastery_Stealthwalker.ApplyAmount3;
	end
	local actions = {};
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, owner, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, owner, eventArg.Buff.name, true, true));
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	return unpack(actions);
end
-- 잠행술의 대가
function Mastery_Stealthwalker_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner 
		or eventArg.Buff.name ~= mastery.Buff.name then
		return;
	end
	local actions = {};
	local addTurn = mastery.ApplyAmount3;
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, owner, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, owner, eventArg.Buff.name, true, true));
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	return unpack(actions);
end
-- 마녀의 바램
function Mastery_WitchGreed_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if eventArg.Buff.Type ~= 'Buff' then
		return;
	end
	if eventArg.Buff.SubType ~= 'Physical' and eventArg.Buff.SubType ~= 'Mental' then
		return;
	end
	if not eventArg.Buff.IsTurnShow then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	local addTurn = mastery.ApplyAmount;
	-- 나태의 마녀
	local mastery_WitchOfSloth = GetMasteryMastered(GetMastery(owner), 'WitchOfSloth');
	if mastery_WitchOfSloth then
		MasteryActivatedHelper(ds, mastery_WitchOfSloth, owner, 'BuffAdded');
		addTurn = addTurn + mastery_WitchOfSloth.ApplyAmount;
	end
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, owner, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, owner, eventArg.Buff.name, true, true));
	return unpack(actions);
end
-- 자가 면역
function Mastery_Autoimmunity_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if eventArg.Buff.Type ~= 'Debuff' then
		return;
	end
	if eventArg.Buff.SubType ~= 'Physical' and eventArg.Buff.SubType ~= 'Mental' then
		return;
	end
	-- 1턴 이하의 디버프에는 적용되지 않음
	if eventArg.Buff.Turn <= 1 then
		return;
	end
	local addTurn = -1 * math.max(1, math.round(eventArg.Buff.Turn * mastery.ApplyAmount2 / 100));
	local actions = {};
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, owner, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, owner, eventArg.Buff.name, true, true));
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	return unpack(actions);
end
-- 살수의 인장
function Mastery_Amulet_Killer_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if eventArg.Unit ~= owner
		or eventArg.Buff.name ~= mastery.Buff.name
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	table.insert(actions, Result_BuffPropertyUpdated('IsTurnShow', false, owner, mastery.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Turn', 99999, owner, mastery.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', 99999, owner, mastery.Buff.name, true, true));
	return unpack(actions);
end
-- 보호색
function Mastery_ProtectiveColoration_BuffAdded(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or GetDistance3D(GetPosition(owner), GetPosition(eventArg.Unit)) > mastery.ApplyAmount + 0.4
		or eventArg.Buff.Type ~= 'Buff'
		or (eventArg.Buff.SubType ~= 'Physical' and eventArg.Buff.SubType ~= 'Mental') then
		return;
	end
	-- 연쇄 발동 방지
	local buffInvoker = SafeIndex(eventArg, 'Invoker');
	if buffInvoker and buffInvoker.Type == 'Mastery' and buffInvoker.Value == mastery.name then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	InsertBuffActions(actions, owner, owner, eventArg.Buff.name, 1, true, nil, nil, {Type = 'Mastery', Value = mastery.name});
	return unpack(actions);
end
-- 광기의 희열
function Mastery_CatharsisOfRage_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount);
	
	local mastery_LastBerserker = GetMasteryMastered(GetMastery(owner), 'LastBerserker');
	if mastery_LastBerserker and (owner.CostType.name == 'Vigor' or owner.CostType.name == 'Rage') then
		AddActionCostForDS(actions, owner, mastery_LastBerserker.ApplyAmount3, true, nil, ds);
		MasteryActivatedHelper(ds, mastery_LastBerserker, owner, 'BuffAdded');
	end
	
	return unpack(actions);
end
-- 좋은 꿈은 전파된다.
function Mastery_DreamDistribute_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Buff.Type ~= 'Buff'
		or (eventArg.Buff.SubType ~= 'Physical' and eventArg.Buff.SubType ~= 'Mental')
		or not HasBuffType(owner, nil, nil, mastery.BuffGroup.name, true) then
		return;
	end
	-- 연쇄 발동 방지
	local buffInvoker = SafeIndex(eventArg, 'Invoker');
	if buffInvoker and buffInvoker.Type == 'Mastery' and buffInvoker.Value == mastery.name then
		return;
	end
	local mission = GetMission(owner);
	local teamUnits = GetTeamUnits(mission, GetTeam(owner));
	teamUnits = table.filter(teamUnits, function(target)
		return target ~= owner and GetBuff(target, eventArg.Buff.name) == nil;
	end);
	if #teamUnits == 0 then
		return;
	end
	local target = teamUnits[math.random(1, #teamUnits)];
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	InsertBuffActions(actions, owner, target, eventArg.Buff.name, 1, true, nil, nil, {Type = 'Mastery', Value = mastery.name});
	return unpack(actions);
end
-- 화공
function Mastery_ConfusionTactics_BuffAdded(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker < 0
		or not IsEnemy(owner, eventArg.Unit)
		or not IsBuffType(eventArg.Buff, 'Debuff', nil, mastery.BuffGroup.name) then
		return;
	end
	local buffInvoker = SafeIndex(eventArg, 'Invoker');
	if not buffInvoker or buffInvoker.Type ~= 'FieldEffect' or buffInvoker.Value ~= mastery.FieldEffect.name then
		return;
	end
	local buffGiver = GetBuffGiver(eventArg.Buff);
	if buffGiver and GetMasteryMastered(GetMastery(buffGiver), 'TrapSystem') then
		buffGiver = GetExpTaker(buffGiver);
	end
	if not buffGiver or buffGiver ~= owner then
		return;
	end
	local target = eventArg.Unit;
	local candidates = GetInstantProperty(owner, mastery.name) or {};
	candidates[GetObjKey(target)] = true;
	SetInstantProperty(owner, mastery.name, candidates);
end
-- 빗나간 죽음
function Mastery_LuckyCheatDeath_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Buff.name ~= mastery.Buff.name then
		return;
	end
	local adjustValue = GetInstantProperty(owner, mastery.name) or 0;
	adjustValue = adjustValue + mastery.ApplyAmount;
	SetInstantProperty(owner, mastery.name, adjustValue);
end
-- 특정 버프 추가 시에 오라 버프 해제 (ex. 디스크 레이돔, 정보 교란기)
function Mastery_AuraDisabledBySubBuff_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Buff.name ~= mastery.SubBuff.name then
		return;
	end
	local auraBuffList = GetInstantProperty(owner, mastery.name);
	if not auraBuffList then
		return;
	end
	local actions = {};
	for _, auraBuff in ipairs(auraBuffList) do
		if HasBuff(owner, auraBuff) then
			table.insert(actions, Result_RemoveBuff(owner, auraBuff, true));
		end
	end
	return unpack(actions);
end
-- 분노 해방
function Mastery_RageLiberation_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	if owner.CostType.name ~= 'Rage' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	AddActionCostForDS(actions, owner, mastery.ApplyAmount, true, nil, ds);
	return unpack(actions);
end
-- 광전사 - 2 세트
function Mastery_BerserkerSet2_BuffAdded(eventArg, mastery, owner, ds)
	if GetBuffGiver(eventArg.Buff) ~= owner
		or not IsBuffType(eventArg.Buff, { 'Buff', 'Debuff' }, nil, mastery.BuffGroup.name) then
		return;
	end
	if not eventArg.Buff.IsTurnShow then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	local addTurn = mastery.ApplyAmount;
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, eventArg.Unit, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, eventArg.Unit, eventArg.Buff.name, true, true));
	return unpack(actions);
end
-- 죽음의 문턱
function Mastery_DeathDoor_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Buff.name ~= mastery.Buff.name then
		return;
	end
	if not eventArg.Buff.IsTurnShow then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	local addTurn = mastery.ApplyAmount;
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, owner, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, owner, eventArg.Buff.name, true, true));
	return unpack(actions);
end
-- 스며드는 독
function Mastery_VenomAbsorb_BuffAdded(eventArg, mastery, owner, ds)
	if GetBuffGiver(eventArg.Buff) ~= owner
		or not IsBuffType(eventArg.Buff, { 'Buff', 'Debuff' }, nil, mastery.BuffGroup.name) then
		return;
	end
	if not eventArg.Buff.IsTurnShow then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	local addTurn = mastery.ApplyAmount;
	-- 맹독술사
	local mastery_Poisonmage = GetMasteryMastered(GetMastery(owner), 'Poisonmage');
	if mastery_Poisonmage then
		MasteryActivatedHelper(ds, mastery_Poisonmage, owner, 'BuffAdded');
		addTurn = addTurn + mastery_Poisonmage.ApplyAmount;
	end	
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, eventArg.Unit, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, eventArg.Unit, eventArg.Buff.name, true, true));
	return unpack(actions);
end
-- 희석
function Mastery_Dilution_BuffAdded(eventArg, mastery, owner, ds)
	if not IsBuffType(eventArg.Buff, 'Debuff', nil, nil) then
		return;
	end
	-- 1(ApplyAmount2)턴 이하의 디버프에는 적용되지 않음
	if eventArg.Buff.Turn <= mastery.ApplyAmount2 then
		return
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	local addTurn = -1 * mastery.ApplyAmount;
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, owner, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, owner, eventArg.Buff.name, true, true));
	return unpack(actions);
end
-- 윤회
function Mastery_Samsara_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Buff.name ~= mastery.Buff.name then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	local addTurn = -1 * mastery.ApplyAmount;
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, owner, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, owner, eventArg.Buff.name, true, true));
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 버프 제거 [BuffRemoved]
----------------------------------------------------------------------------
-- 어둠추적자 - 5 세트
---@param owner unit
function Mastery_DarkChaserSet5_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end

	local actions = {};
	if owner.TurnState.TurnEnded then
		table.insert(actions, Result_PropertyUpdated('TurnState/TurnEnded', false, owner, true));
		table.insert(actions, Result_PropertyUpdated('Act', 0, owner, true));
	end
	AddActionRestoreActions(actions, owner);
	MasteryActivatedHelper(ds, mastery, owner, 'BuffRemoved_Self');
	return unpack(actions);
end
-- 행운수집가
function Mastery_FortuneCollector_BuffRemoved(eventArg, mastery, owner, ds)	
	if eventArg.BuffName ~= mastery.Buff.name then
		return;
	end
	
	local actions = {};
	AddActionApplyActForDS(actions, owner, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	return unpack(actions);
end
function Mastery_Awakening_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.BuffName ~= mastery.SubBuff.name then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'BuffRemoved'});
	return unpack(actions);
end
-- 꿈속의 꿈
function Mastery_DreamInDream_BuffRemoved(eventArg, mastery, owner, ds)
	if not IsBuffType(eventArg.Buff, 'Debuff', nil, mastery.BuffGroup.name) then
		return;
	end
	
	if not RandomTest(mastery.ApplyAmount) then
		return;
	end
	
	local picker = RandomBuffPicker.new(owner, GetClassList('BuffGroup').Sleep.BuffList);
	local buff = picker:PickBuff();
	if buff == nil then
		return;
	end
	
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff, 1, true);
	MasteryActivatedHelper(ds, mastery, owner, 'BuffRemoved_Self');
	return unpack(actions);
end
-- 숙면
function Mastery_DeepSleep_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	
	local cacheKey = 'DeepSleep_ExpCache_'..eventArg.Buff.name;
	local cache = GetInstantProperty(owner, cacheKey);
	if cache == nil then
		LogAndPrint('Mastery_DeepSleep_BuffRemoved', 'Exp Cache Data 소실', eventArg.Buff.name);
		return;
	end
	
	
	SetInstantProperty(owner, cacheKey, nil);
	if eventArg.Buff.Life > 0 then
		-- 라이프가 남아있음. 시간흐름으로 풀린게 아님
		return;
	end
	
	local addExp = math.floor(CalculateExpDiff(owner.ExpType, cache.Lv, cache.Exp, owner.Lv, owner.Exp) * mastery.ApplyAmount / 100);
	local addJobExp = math.floor(CalculateExpDiff(owner.JobExpType, cache.JobLv, cache.JobExp, owner.JobLv, owner.JobExp) * mastery.ApplyAmount / 100);
	
	
	local reason = 'Mastery_'..mastery.name;
	local action = Result_AddExp(owner, addExp, addJobExp, reason);
	
	-- 휴식 경험치 경감
	owner.RestExp = math.max(0, owner.RestExp - addExp);
	owner.RestJobExp = math.max(0, owner.RestJobExp - addJobExp);
	
	-- 연출 처리
	local objKey = GetObjKey(owner);
	local team = GetTeam(owner);
	local addExpCmd = ds:PlayUIEffect(objKey, '_CENTER_', 'AddExp', 6, 2, PackTableToString({exp = addExp, reason = reason, AliveOnly=true, Team = team}));
	local upExpReal, jobExpReal = GetRealExpFromAction(action);
	if upExpReal and upExpReal > 0 then
		local chatCmd = ds:AddMissionChat('AddExp', 'AddExp', {ObjectKey = objKey, Exp = addExp, Reason = reason, Team = team});
		ds:Connect(chatCmd, addExpCmd, 0);
	end
	if jobExpReal and jobExpReal > 0 then
		local chatCmdJob = ds:AddMissionChat('AddExp', 'AddJobExp', {ObjectKey = objKey, Exp = addJobExp, Reason = reason, Team = team});
		ds:Connect(chatCmdJob, addExpCmd, 0);
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'BuffRemoved_Self', nil, addExpCmd, 0);
	
	return action;
end
-- 함정 시스템
function Mastery_TrapSystem_BuffRemoved(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker == 0 
		or owner.Detected then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
-- 특정 버프 해제 시에 오라 버프 복원 (ex. 디스크 레이돔, 정보 교란기)
function Mastery_AuraDisabledBySubBuff_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Buff.name ~= mastery.SubBuff.name then
		return;
	end
	local auraBuffList = GetInstantProperty(owner, mastery.name);
	if not auraBuffList then
		return;
	end
	local actions = {};
	for _, auraBuff in ipairs(auraBuffList) do
		if not HasBuff(owner, auraBuff) then
			table.insert(actions, Result_AddBuff(owner, owner, auraBuff, 1, nil, true));
		end
	end
	return unpack(actions);
end
-- 광전사 인장
function Mastery_Amulet_Berserker_Set_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	-- 분노 계열 상태가 하나라도 남아있으면 카운트 유지
	if HasBuffType(owner, nil, nil, mastery.BuffGroup.name, true) then
		return;
	end
	mastery.CountChecker = 0;
end
-- 멍고 은신처
function Mastery_CoverHideout_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Buff.name ~= mastery.Buff.name and eventArg.Buff.name ~= 'Conceal_For_Aura' then
		return;
	end
	if owner.HP >= owner.MaxHP then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffRemoved');
	local addHP = math.floor(owner.MaxHP * mastery.ApplyAmount / 100);
	local reasons = {};
	addHP, reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false);
	AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	return unpack(actions);
end
-------------------------------------------------------------------------------
-- 버프 프로퍼티 갱신 [BuffPropertyUpdated]
-------------------------------------------------------------------------------
-- 분노 해방
function Mastery_RageLiberation_BuffPropertyUpdated(eventArg, mastery, owner, ds)
	if eventArg.Buff.Group ~= mastery.BuffGroup.name 
		or eventArg.PropertyName ~= 'Lv' then
		return;
	end
	if owner.CostType.name ~= 'Rage' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffPropertyUpdated');
	AddActionCostForDS(actions, owner, mastery.ApplyAmount, true, nil, ds);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 팀 변경 [UnitTeamChanged]
----------------------------------------------------------------------------
-- 야수 단결
function Mastery_BeastBond_UnitTeamChanged(eventArg, mastery, owner, ds)
	local beastInfo = GetInstantProperty(owner, 'SummonBeast');
	if beastInfo == nil or beastInfo.Owner ~= owner then
		return;
	end
	local beast = beastInfo.Target;
	if (eventArg.Unit ~= owner and eventArg.Unit ~= beast)
		or GetRelation(owner, beast) ~= 'Enemy' then
		return;
	end

	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, mastery.Buff.name));
	table.insert(actions, Result_RemoveBuff(beast, mastery.Buff.name));
	return unpack(actions);
end
-- 함정 시스템
function Mastery_TrapSystem_UnitTeamChanged(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 팀 변경이 되었으므로 범위표기 갱신
	local mvrKey = string.format('TRAP_AREA:%s', GetObjKey(owner));
	
	UnregisterConnectionRestoreRoutine(GetMission(owner), mvrKey);
	ds:MissionVisualRange_AddCustom(mvrKey, false, nil, GetObjKey(owner));
	
	RegisterConnectionRestoreRoutine(GetMission(owner), mvrKey, function(ds)
		ds:MissionVisualRange_AddCustom(mvrKey, true, GetPosition(owner), GetObjKey(owner), 'Sphere2_Trap_Ally','Sphere2_Trap');
	end);
	ds:MissionVisualRange_AddCustom(mvrKey, true, GetPosition(owner), GetObjKey(owner), 'Sphere2_Trap_Ally','Sphere2_Trap');
	
	local trapHost = GetExpTaker(owner);
	-- 괴수 사냥꾼 - 2 세트
	local mastery_MonsterHunterSet2 = GetMasteryMastered(GetMastery(trapHost), 'MonsterHunterSet2');
	if mastery_MonsterHunterSet2 then
		local allyRange = 'Sphere3_Trap_Assist_Dot';
		local enemyRange = 'Sphere3_Trap_Dot';
		local mvrKey2 = string.format('TRAP_AREA_APPLY:%s', GetObjKey(owner));
		
		UnregisterConnectionRestoreRoutine(GetMission(owner), mvrKey2);
		ds:MissionVisualRange_AddCustom(mvrKey2, false, nil, GetObjKey(owner));
		
		RegisterConnectionRestoreRoutine(GetMission(owner), mvrKey2, function(ds)
			ds:MissionVisualRange_AddCustom(mvrKey2, true, GetPosition(owner), GetObjKey(owner), allyRange, enemyRange);
		end);
		ds:MissionVisualRange_AddCustom(mvrKey2, true, GetPosition(owner), GetObjKey(owner), allyRange, enemyRange);
	end	
end
--------------------------------------------------------------------------------
-- 아이템 획득 [UnitItemAcquired]
----------------------------------------------------------------------------
-- 황금의 도시
function Mastery_GoldenCity_UnitItemAcquired(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local itemRank = eventArg.Item.Rank.name;
	if itemRank ~= 'Legend' and itemRank ~= 'Epic' and itemRank ~= 'Rare' and itemRank ~= 'Uncommon' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitItemAcquired_Self');
	if itemRank == 'Legend' then
		local addHP = math.floor(owner.MaxHP * mastery.ApplyAmount2 / 100);
		local reasons = {};
		addHP, reasons = AddActionRestoreHP(actions, owner, owner, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false);
		AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	elseif itemRank == 'Epic' then
		local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
		local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
		local goodBuff = goodBuffPicker:PickBuff();
		if goodBuff ~= nil then
			InsertBuffActions(actions, owner, owner, goodBuff, 1);
		end
	elseif itemRank == 'Rare' then
		local ownerKey = GetObjKey(owner);
		local applyAct = -1 * mastery.ApplyAmount;
		local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
		if added then
			ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	elseif itemRank == 'Uncommon' and owner.CostType.name == 'Vigor' then
		local ownerKey = GetObjKey(owner);
		local addCost = mastery.ApplyAmount;
		local _, reasons = AddActionCost(actions, owner, addCost, true);
		ds:UpdateBattleEvent(ownerKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost });
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
	return unpack(actions);
end
-- 채워지지 않는 탐욕
function Mastery_Greedthirst_UnitItemAcquired(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	af:ApplyAct(owner, owner, -mastery.ApplyAmount, 'Friendly');
	-- 강렬한 생존 욕구
	af:AddSynergyMasteryAction(owner, 'GreedOfLife', function(mastery_GreedOfLife)
		af:AddHP(owner, owner, math.floor(owner.MaxHP * mastery_GreedOfLife.ApplyAmount / 100));
	end);
	return af:UnpackActions('UnitItemAcquired_Self');
end
-- 무자비한 약탈
function Mastery_BrutalityPlunder_UnitItemAcquired(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitItemAcquired');
	-- 채워지지 않는 탐욕
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	-- 탐욕의 눈
	local itemCategory = eventArg.Item.Category.name;
	if itemCategory == 'Jewel' then
		AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 유닛 레벨업 [UnitLvAdded]
----------------------------------------------------------------------------
function Mastery_RoadOfStudies_UnitLvAdded(eventArg, mastery, owner, ds)
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, eventArg.EventType);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 유닛 경험치 획득 [UnitExpAdded]
----------------------------------------------------------------------------
function Mastery_RoadOfStudies_UnitExpAdded(eventArg, mastery, owner, ds)
	local expInfo = GetInstantProperty(owner, mastery.name) or { Lv = owner.Lv, Exp = 0 };
	expInfo.Exp = expInfo.Exp + eventArg.ExpBase;
	SetInstantProperty(owner, mastery.name, expInfo);
end
--------------------------------------------------------------------------------
-- 유닛 생성 [UnitCreated]
----------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 유닛 상호 작용 [UnitInteractObject]
----------------------------------------------------------------------------
function Mastery_RepairableObject_UnitInteractObject(eventArg, mastery, owner, ds)
	if eventArg.Interaction.name ~= 'Repair'
		or eventArg.Target ~= owner then
		return;
	end
	local disabledMonType = GetInstantProperty(owner, 'DisabledMonsterType');
	local direction = GetDirection(owner);
	local newObjKey = GenerateUnnamedObjKey(GetMission(owner));
	local destroy = Result_DestroyObject(owner, false, true);
	local create = Result_CreateMonster(newObjKey, disabledMonType, GetPosition(owner), '_neutral_', function(obj, arg)
		UNIT_INITIALIZER(obj, GetTeam(obj));
		SetDirection(obj, direction);
	end, nil, 'DoNothingAI', {}, true);
	destroy.sequential = true;
	create.sequential = true;
	return destroy, create;
end
--------------------------------------------------------------------------------
-- 전투 돌입 [RunIntoBattle]	Args: Unit(object), Trigger(object), BuffType(string)
----------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 우호적 야수 참전 (야수 소환/길들이기) [FriendlyBeastHasJoined]	Args: Beast(object), Tamer(object), FirstJoin(boolean)
----------------------------------------------------------------------------
-- 야수 동화
function Mastery_BeastAssimilation_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if eventArg.Tamer ~= owner then
		return;
	end
	local actions = {};

	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	InsertBuffActions(actions, owner, eventArg.Beast, mastery.Buff.name, 1, true);
	MasteryActivatedHelper(ds, mastery, owner, 'FriendlyBeastHasJoined');
	
	return unpack(actions);
end
function Mastery_BeastAssimilation_FriendlyBeastHasJoinedPre(eventArg, mastery, owner, ds)
	if not eventArg.FirstJoin or GetObjKey(owner) ~= GetInstantProperty(eventArg.Beast, 'SummonMaster') then
		return;
	end
	local reinforceMastery = 'BeastAssimilation_Beast';
	local actions = {};
	table.insert(actions, Result_UpdateMastery(eventArg.Beast, reinforceMastery, 1));
	return unpack(actions);
end
-- 야수 교감
function Mastery_BeastCommunion_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if eventArg.Tamer ~= owner then
		return;
	end

	local beastTypeFlag = GetInstantProperty(owner, 'BeastCommunion') or {};
	beastTypeFlag[eventArg.Beast.Job.name] = true;

	local actions = {Result_UpdateInstantProperty(owner, 'BeastCommunion', beastTypeFlag, true)};

	Mastery_BeastCommunion_BeastChanged_Shared(actions, eventArg, owner);

	if eventArg.Beast.Job.name == 'Neguri' then
		local actions = {};
		local buffList = GetBuffType(owner, nil, 'Physical');
		for _, rb in ipairs(buffList) do
			InsertBuffActions(actions, owner, owner, rb.name, -rb.Lv, true);
			ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = rb.name, EventType = 'Ending' });
		end
		if #buffList > 0 then
			MasteryActivatedHelper(ds, mastery, owner, 'FriendlyBeastHasJoined');
		end
	end

	return unpack(actions);
end
-- 선조의 기록
function Mastery_HeredityExpression_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if not eventArg.FirstJoin 
		or not IsPlayerTeam(owner) 
		or owner ~= eventArg.Beast then
		return;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	local UpdateRefMasteries = function(hostMastery, cnt)
		local refKeys = {'RefMastery', 'RefMastery2', 'RefMastery3', 'RefMastery4'};
		for i = 1, math.min(cnt, #refKeys) do
			if hostMastery[refKeys[i]] ~= 'None' then
				ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = hostMastery[refKeys[i]] });
			end
		end
	end
	UpdateRefMasteries(mastery, mastery.ApplyAmount);
	local mastery_AncestorsSuccession = GetMasteryMastered(GetMastery(owner), 'AncestorsSuccession');
	if mastery_AncestorsSuccession then
		MasteryActivatedHelper(ds, mastery_AncestorsSuccession, owner, 'UnitTurnStart_Self');
		UpdateRefMasteries(mastery_AncestorsSuccession, mastery_AncestorsSuccession.ApplyAmount + mastery_AncestorsSuccession.ApplyAmount2 + mastery_AncestorsSuccession.ApplyAmount3);
	end
end
-- 휴식 훈련
function Mastery_RestTraining_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if eventArg.Beast ~= owner or IsDead(owner) then
		return;
	end
	local unsummonTime = GetInstantProperty(owner, 'UnsummonTime');
	if unsummonTime == nil then
		return;
	end
	
	local thisTime = GetMissionElapsedTime(owner);
	local recoveryAmount = math.floor((thisTime - unsummonTime) / mastery.ApplyAmount) * mastery.ApplyAmount2 / 100 * owner.MaxHP;
	return Result_PropertyUpdated('HP', math.floor(owner.HP + recoveryAmount), owner, true);
end
-- 야수 훈련
function Mastery_BeastTraining_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if not eventArg.FirstJoin or GetObjKey(owner) ~= GetInstantProperty(eventArg.Beast, 'SummonMaster') then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	local actions = {};
	table.insert(actions, Result_UpdateMastery(eventArg.Beast, reinforceMastery.name, 1));
	return unpack(actions);
end
-- 야수 결속 (야수쪽 버프 강화를 위한 시스템 마스터리 추가
function Mastery_BeastStrongBond_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if not eventArg.FirstJoin or GetObjKey(owner) ~= GetInstantProperty(eventArg.Beast, 'SummonMaster') then
		return;
	end
	local reinforceMastery = 'BeastStrongBond_Beast';
	local actions = {};
	table.insert(actions, Result_UpdateMastery(eventArg.Beast, reinforceMastery, 1));
	return unpack(actions);
end
-- 괴수 사냥군
function Mastery_MonsterHunter_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if not eventArg.FirstJoin or GetObjKey(owner) ~= GetInstantProperty(eventArg.Beast, 'SummonMaster') then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	local actions = {};
	table.insert(actions, Result_UpdateMastery(eventArg.Beast, reinforceMastery.name, 1));
	return unpack(actions);
end
-- 사냥꾼의 일상
function Mastery_LifeOfHunter_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= GetInstantProperty(eventArg.Beast, 'SummonMaster') then
		return;
	end
		
	SetInstantProperty(eventArg.Beast, 'DailyHuntingNow', true);
end
-- 돌입 훈련
function Mastery_RushTraining_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if owner ~= eventArg.Beast then
		return;
	end
	SubscribeWorldEvent(owner, 'UnitTurnStart_Self', function(eventArg, ds, subscriptionID)
		UnsubscribeWorldEvent(owner, subscriptionID);
		MasteryActivatedHelper(ds, mastery, owner, 'FriendlyBeastHasJoined');
	end);
	return Result_PropertyUpdated('Act', -owner.Speed, owner, true, true);
end
--------------------------------------------------------------------------------
-- 우호적 야수 떠남 (야수 해제) [FriendlyBeastAboutToLeave]	Args: Beast(object), Tamer(object)
----------------------------------------------------------------------------
-- 야수 단결
function Mastery_BeastBond_FriendlyBeastAboutToLeave(eventArg, mastery, owner, ds)
	if eventArg.Tamer ~= owner then
		return;
	end

	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, mastery.Buff.name));
	table.insert(actions, Result_RemoveBuff(eventArg.Beast, mastery.Buff.name));
	return unpack(actions);
end
-- 야수 교감
function Mastery_BeastCommunion_BeastChanged_Shared(actions, eventArg, owner)
	if eventArg.Beast.Job.name == 'Dorori' then
		table.insert(actions, Result_InvalidateObject(owner, 'SightRange'));
		table.insert(actions, Result_InvalidateObject(owner, 'MoveDist'));
	elseif eventArg.Beast.Job.name == 'Neguri' then
		table.insert(actions, Result_InvalidateObject(owner, 'ImmuneDebuff_Physical'));
	end
end
function Mastery_BeastCommunion_FriendlyBeastAboutToLeave(eventArg, mastery, owner, ds)
	if eventArg.Tamer ~= owner then
		return;
	end

	local beastTypeFlag = GetInstantProperty(owner, 'BeastCommunion') or {};
	beastTypeFlag[eventArg.Beast.Job.name] = nil;

	local actions = {Result_UpdateInstantProperty(owner, 'BeastCommunion', beastTypeFlag, true)};

	Mastery_BeastCommunion_BeastChanged_Shared(actions, eventArg, owner);

	return unpack(actions);
end
-- 사냥꾼의 일상
function Mastery_LifeOfHunter_FriendlyBeastAboutToLeave(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= GetInstantProperty(eventArg.Beast, 'SummonMaster') then
		return;
	end
	SetInstantProperty(eventArg.Beast, 'DailyHuntingNow', nil);
end
-- 휴식 훈련
function Mastery_RestTraining_FriendlyBeastAboutToLeave(eventArg, mastery, owner, ds)
	if eventArg.Beast ~= owner then
		return;
	end
	local actions = {};
	-- 소환 해제 시간 설정
	table.insert(actions, Result_UpdateInstantProperty(owner, 'UnsummonTime', GetMissionElapsedTime(owner)));
	-- 상태 이상 해제
	local removeBuffList = GetBuffType(owner, 'Debuff');
	local objKey = GetObjKey(owner);
	for _, buff in ipairs(removeBuffList) do
		table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
		ds:UpdateBattleEvent(objKey, 'BuffDischarged', { Buff = buff.name });
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 적에게 내 야수를 뺏김 [EnemyHasCapturedMyBeast]	Args: Taker(object), Beast(object)
----------------------------------------------------------------------------
-- 야수 단결
function Mastery_BeastBond_EnemyHasCapturedMyBeast(eventArg, mastery, owner, ds)
	local beastInfo = GetInstantProperty(owner, 'SummonBeast');
	if beastInfo == nil or beastInfo.Owner ~= owner then
		return;
	end
	local beast = beastInfo.Target;

	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, mastery.Buff.name));
	table.insert(actions, Result_RemoveBuff(beast, mastery.Buff.name));
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 우호적 기계 참전 (기계 소환/제어권 탈취) [FriendlyMachineHasJoined]	Args: Machine(object), FirstJoin(boolean)
----------------------------------------------------------------------------
-- 해체 전문가
function Mastery_DismantlingSpecialist_FriendlyMachineHasJoined(eventArg, mastery, owner, ds)
	-- 기계 소환도 아니고, 제어권 탈취도 아니면 무시
	local isSummoned = GetObjKey(owner) == GetInstantProperty(eventArg.Machine, 'SummonMaster');
	local isHacked = Set.new(GetInstantProperty(owner, 'ControlTakingOverTargets') or {})[GetObjKey(eventArg.Machine)];
	if not isSummoned and not isHacked then
		return;
	end
	SetInstantProperty(eventArg.Machine, 'DismantlingSpecialist', true);
end
-- XX역학 (동역학, 고체역학, 유체역학, 열역학 등)
function Mastery_CommonMechanics_FriendlyMachineHasJoined(eventArg, mastery, owner, ds)
	-- 기계 소환도 아니고, 제어권 탈취도 아니면 무시
	local isSummoned = GetObjKey(owner) == GetInstantProperty(eventArg.Machine, 'SummonMaster');
	local isHacked = Set.new(GetInstantProperty(owner, 'ControlTakingOverTargets') or {})[GetObjKey(eventArg.Machine)];
	if not isSummoned and not isHacked then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	return Result_UpdateMastery(eventArg.Machine, reinforceMastery.name, 1);
end
-- 개선된 기계 소환
function Mastery_FineTuningMachineStart_FriendlyMachineHasJoined(eventArg, mastery, owner, ds)
	-- 기계 소환이 아니면 무시
	local isSummoned = GetObjKey(owner) == GetInstantProperty(eventArg.Machine, 'SummonMaster');
	if not isSummoned then
		return;
	end
	local applyAmount = 0;
	local espType = eventArg.Machine.ESP.name;
	if espType == 'Info' then
		applyAmount = mastery.ApplyAmount;
	elseif espType == 'Heat' then
		applyAmount = mastery.ApplyAmount2;
	elseif espType == 'Charge' then
		applyAmount = mastery.ApplyAmount3;
	else
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'FriendlyMachineHasJoined');
	AddActionApplyActForDS(actions, owner, eventArg.Machine, -applyAmount, ds, 'Friendly');
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 우호적 기계 떠남 (기계 해제) [FriendlyMachineAboutToLeave]	Args: Machine(object), MasterKey(string, object key)
----------------------------------------------------------------------------
-- 해체 전문가
function Mastery_DismantlingSpecialist_FriendlyMachineAboutToLeave(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= eventArg.MasterKey then
		return;
	end
	SetInstantProperty(eventArg.Machine, 'DismantlingSpecialist', nil);
end
-- XX역학 (동역학, 고체역학, 유체역학, 열역학 등)
function Mastery_CommonMechanics_FriendlyMachineAboutToLeave(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= eventArg.MasterKey then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	return Result_UpdateMastery(eventArg.Machine, reinforceMastery.name, -1);
end
--------------------------------------------------------------------------------
-- 순찰 회피 [PatrolAvoided]	Args: Unit(object), Buff(buff)
----------------------------------------------------------------------------
-- 위장
function Mastery_Camouflage_PatrolAvoided(eventArg, mastery, owner, ds)
	if owner == eventArg.Unit then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'PatrolAvoided');
	
	local actions = {};
	-- 설계된 함정
	local mastery_TrapDesign = GetMasteryMastered(GetMastery(owner), 'TrapDesign');
	if mastery_TrapDesign then
		AddActionApplyActForDS(actions, owner, owner, -mastery_TrapDesign.ApplyAmount2, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_TrapDesign, owner, 'PatrolAvoided');
	end
	
	-- 달빛 사냥꾼
	local mastery_MoonHunter = GetMasteryMastered(GetMastery(owner), 'MoonHunter');
	if mastery_MoonHunter and IsDarkTime(GetMission(owner).MissionTime.name) then
		if AddRandomGoodBuffAction(actions, owner, owner) then
			MasteryActivatedHelper(ds, mastery_MoonHunter, owner, 'PatrolAvoided');
		end
	end
	
	return unpack(actions);
end
-- MyTrapActivated	내 트랩 발동!
function Mastery_AttackWithBeast_MyTrapActivated(eventArg, mastery, owner, ds)
	local allowTargets = {};
	for _, obj in ipairs(eventArg.ApplyTargets) do
		if not IsDead(obj) then
			allowTargets[GetObjKey(obj)] = true;
		end
	end
	return Mastery_AttackWithBeastActivated(allowTargets, mastery, owner, ds, true);
end
--------------------------------------------------------------------------------
-- 시민 구출 [CitizenRescued]
----------------------------------------------------------------------------
function Mastery_MyDreamIsHero_CitizenRescued(eventArg, mastery, owner, ds)
	if eventArg.Savior ~= owner
		or GetBuff(owner, mastery.Buff.name) == nil then
		return;
	end
	return Mastery_MyDreamIsHero_ActivatePositiveEffect(mastery, owner, ds);
end
function Mastery_MyDreamIsHero_ActivatePositiveEffect(mastery, owner, ds)
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	
	local goodBuff = goodBuffPicker:PickBuff();
	if goodBuff == nil then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'Etc');
	local actions = {};
	InsertBuffActions(actions, owner, owner, goodBuff, 1, true);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 덫 파괴 [TrapHasBeenCracked]
----------------------------------------------------------------------------
function Mastery_TrapSystem_TrapHasBeenCracked(eventArg, mastery, owner, ds)
	ds:UpdateBattleEvent(GetObjKey(owner), eventArg.BattleEvent or 'Malfunction', {});
	ds:PlayParticle(GetObjKey(owner), '_CENTER_', 'Particles/Dandylion/Muzzle_Explosion', 1, true, true, false);
	return Result_PropertyUpdated('Base_Detected', true, owner), Result_DestroyObject(owner, true);
end
--------------------------------------------------------------------------------
-- XX 쐐기 발동 [BoltInvoked]
----------------------------------------------------------------------------
-- 얼음 파편
function Mastery_IceFraction_BoltInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or not HasBuffType(eventArg.Target, 'Debuff', nil, mastery.BuffGroup.name) then
		return;
	end
	local addBuff = mastery.Buff.name;
	-- 얼어붙은 검
	local mastery_FrozenSword = GetMasteryMastered(GetMastery(owner), 'FrozenSword');
	if mastery_FrozenSword then
		addBuff = mastery_FrozenSword.Buff.name;
	end
	
	local alreadyBuff = GetBuff(eventArg.Target, addBuff);
	if alreadyBuff and alreadyBuff.Age == 0 then
		return;
	end
	
	local actions = {};
	InsertBuffActions(actions, owner, eventArg.Target, addBuff, 1, true, nil, true);
	MasteryActivatedHelper(ds, mastery, eventArg.Target, 'BoltInvoked');
	return unpack(actions);
end
-- XX 쐐기 공용
function Mastery_BoltCommon_BoltInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery.name then
		return;
	end
	local target = eventArg.Target;
	local damage = eventArg.Damage;	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEventTargetDamage', {ObjectKey = GetObjKey(owner), TargetKey = GetObjKey(target), MasteryType = mastery.name, Damage = damage});
end
-- 불꽃 쐐기
function Mastery_FlameBolt_BoltInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Mastery ~= 'FireBolt'
		or eventArg.Damage <= 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'Etc');
	local target = eventArg.Target;
	if not HasBuff(target, mastery.Buff.name) then
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	else
		InsertBuffActions(actions, owner, target, mastery.SubBuff.name, 1, true);
	end
	return unpack(actions);
end
-- 서리 쐐기
function Mastery_FrostBolt_BoltInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Mastery ~= 'IceBolt'
		or eventArg.Damage <= 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'Etc');
	local target = eventArg.Target;
	-- 턴 대기 시간 증가
	if HasBuffType(target, 'Debuff', nil, mastery.BuffGroup.name) then
		AddActionApplyActForDS(actions, owner, target, mastery.ApplyAmount, ds, 'Hostile');
	end
	-- 버프 추가
	if not HasBuff(target, mastery.Buff.name) then
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	else
		InsertBuffActions(actions, owner, target, mastery.SubBuff.name, 1, true);
	end
	return unpack(actions);
end
-- 섬광 쐐기
function Mastery_FlashBolt_BoltInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Mastery ~= 'LightningBolt'
		or eventArg.Damage <= 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'Etc');
	local target = eventArg.Target;
	-- 턴 대기 시간 감소
	if HasBuffType(target, 'Debuff', nil, mastery.BuffGroup.name) then
		AddActionApplyActForDS(actions, owner, owner, -1 * mastery.ApplyAmount, ds, 'Friendly');
	end
	-- 버프 추가
	if not HasBuff(target, mastery.Buff.name) then
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	else
		InsertBuffActions(actions, owner, target, mastery.SubBuff.name, 1, true);
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 은신 발각 [CloakingDetected]
----------------------------------------------------------------------------
function Mastery_FullyReady_CloakingDetected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Unit == nil
		or owner.HP < 0 then
		return;
	end
	local allowTargets = {};
	allowTargets[GetObjKey(eventArg.Unit)] = true;
	
	-- 궁극기를 제외한 공격 어빌리티
	local abilities = table.filter(GetAvailableAbility(owner, true), function (ability) return ability.Type == 'Attack' and not ability.SPFullAbility end);
	abilities = SortAbilityList(owner, abilities);
	local abilityRank = {};
	for i, ability in ipairs(abilities) do
		abilityRank[ability.name] = #abilities - i;
	end
	
	local usingAbility, usingPos, _, score = FindAIMainAction(owner, abilities, {{Strategy = function(self, adb)
		local count = table.count(adb.ApplyTargets, function(t) return allowTargets[GetObjKey(t)] end);
		if count == 0 then
			return -22;
		end
		local score = 100;
		if adb.IsIndirect then
			score = 0;
		end
		score = score + abilityRank[adb.Ability.name] * 200;
		return score + 100 / (adb.Distance + 1);
	end, Target = 'Attack'}}, {}, {});
	
	if usingAbility == nil or usingPos == nil then
		return;
	end
	
	local actions = {};
	
	local action, reasons = GetApplyActAction(owner, mastery.ApplyAmount, nil, 'Cost');
	local battleEvents = {};
	if action then
		table.insert(actions, action);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = mastery.ApplyAmount } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	table.insert(battleEvents, {Object = owner, EventType = 'MasteryInvokedCustomEvent', Args = {Mastery = mastery.name, EventType = 'CloakingDetected', MissionChat = true} });
	-- 밤추적자
	local inevitable = nil;
	local mastery_NightChaser = GetMasteryMastered(GetMastery(owner), 'NightChaser');
	if mastery_NightChaser and IsDarkTime(GetMission(owner).MissionTime.name) then
		inevitable = true;
	end
	local overwatchAction = Result_UseAbility(owner, usingAbility.name, usingPos, {ReactionAbility=true, BattleEvents=battleEvents, Inevitable=inevitable}, true, {});
	overwatchAction.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, usingAbility.TargetRange, GetPosition(owner)), usingPos);
	end;
	overwatchAction.on_success_actions = actions;
	
	return overwatchAction;
end
--------------------------------------------------------------------------------
-- 공연 효과 발생 [PerformanceEffectAdded]
----------------------------------------------------------------------------
-- 공연시스템
function Mastery_PerformanceSystem_PerformanceEffectAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or owner.PerformanceType == 'None' then
		return;
	end
	local performanceCls = GetClassList('Performance')[owner.PerformanceType];
	if not performanceCls then
		return;
	end
	
	local masteryTable = GetMastery(owner);

	local actions = {};
	local performanceList = GetInstantProperty(owner, 'PerformanceList') or {};
	
	-- 슬롯 4개씩 멋짐 체크
	if #performanceList >= 4 then
		local greatList = {};
		while true do
			local prevCount = #greatList;
			for i = 1, #performanceList - 3 do
				local effect1 = performanceList[i];
				local effect2 = performanceList[i + 1];
				local effect3 = performanceList[i + 2];
				local effect4 = performanceList[i + 3];
				local greatCls = TestPerformanceGreatType(performanceCls, effect1, effect2, effect3, effect4);
				if greatCls then
					table.insert(greatList, greatCls);
					for j = 3, 0, -1 do
						table.remove(performanceList, i + j);
					end
					-- 정기 공연
					local mastery_SubscriptionConcert = GetMasteryMastered(masteryTable, 'SubscriptionConcert');
					if mastery_SubscriptionConcert then
						table.insert(performanceList, i, effect4);
					end
					break;
				end
			end
			if prevCount == #greatList then
				break;
			end
		end
		if #greatList > 0 then		
			for _, greatCls in ipairs(greatList) do
				AddPerformanceGreatActionForDS(actions, owner, greatCls, ds);
			end
		end
	end
	
	-- 마무리 체크
	-- 즉흥적인 마무리
	local hasShowClose = false;
	if eventArg.Ability ~= 'ShowClose' and HasBuff(owner, 'ShowClose') then
		hasShowClose = true;
	end
	if hasShowClose or #performanceList >= owner.PerformanceSlot then
		local greatLv = owner.PerformanceGreatLv;
		local prevList = table.deepcopy(performanceList);
		-- 마무리 발동
		AddPerformanceFinishActionForDS(actions, owner, performanceCls, greatLv, #performanceList, ds);
		-- 슬롯 비움
		performanceList = {};
		-- 앙코르
		local mastery_Encore = GetMasteryMastered(masteryTable, 'Encore');
		if mastery_Encore then
			local insertCount = math.min(greatLv, owner.PerformanceSlot - mastery_Encore.ApplyAmount);
			if insertCount > 0 then
				for i = 1, insertCount do 
					table.insert(performanceList, prevList[i]);
				end
			end
		end
		if hasShowClose then
			table.insert(actions, Result_RemoveBuff(owner, 'ShowClose', true));
		end
	end	

	-- 남은 슬롯 반영
	table.insert(actions, Result_UpdateInstantProperty(owner, 'PerformanceList', performanceList, true));
	-- 액션이 처리되기 전의 서버 로직에서 반영되도록 바로 적용
	SetInstantProperty(owner, 'PerformanceList', performanceList);
	
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 공연 멋짐 발생 [PerformanceGreatInvoked]
----------------------------------------------------------------------------
-- 각광
function Mastery_Spotlight_PerformanceGreatInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'PerformanceGreatInvoked');
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	AddActionCostForDS(actions, owner, mastery.ApplyAmount, true, nil, ds);
	AddActionApplyActForDS(actions, owner, owner, -1 * mastery.ApplyAmount2, ds, 'Friendly');
	return unpack(actions);
end
----------------------------------------------------------------------------
-- 공연 마무리 발생 [PerformanceFinishInvoked]
----------------------------------------------------------------------------
-- 앙코르 공연
function Mastery_EncoreStage_PerformanceFinishInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.GreatLv < mastery.ApplyAmount then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'PerformanceFinishInvoked');
	AddActionRestoreActions(actions, owner);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 구조 요청 접수 [RescueCallReceived]
----------------------------------------------------------------------------
-- 응급 구조 프로그램
function Mastery_Module_EmergencyRescue_EmergencyRescueReceived(eventArg, mastery, owner, ds)
	if owner == eventArg.Receptionist then
		return;
	end
	local onGoingRescueTargets = GetInstantProperty(owner, 'OnGoingRescueTargets') or {};
	onGoingRescueTargets[GetObjKey(eventArg.Target)] = true;
	SetInstantProperty(owner, 'OnGoingRescueTargets', onGoingRescueTargets);
end
--------------------------------------------------------------------------------
-- 구조 요청 완료 [RescueCallCompleted]
----------------------------------------------------------------------------
-- 응급 구조 프로그램
function Mastery_Module_EmergencyRescue_EmergencyRescueCompleted(eventArg, mastery, owner, ds)
	local onGoingRescueTargets = GetInstantProperty(owner, 'OnGoingRescueTargets') or {};
	onGoingRescueTargets[GetObjKey(eventArg.Target)] = nil;
	SetInstantProperty(owner, 'OnGoingRescueTargets', onGoingRescueTargets);
end
--------------------------------------------------------------------------------
-- 버프 면역 적용 [BuffImmuned]
----------------------------------------------------------------------------
function Mastery_BigLightningRod_BuffImmuned(eventArg, mastery, owner, ds)
	if eventArg.Reason ~= 'Mastery_LightningRod'
		or owner.ESP.name ~= mastery.Type.name then	-- 번개 SP체크
		return;
	end
	
	local actions = {};
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	MasteryActivatedHelper(ds, mastery, owner, 'BuffImmuned_Self');
	return unpack(actions);
end
-- 지배자
function Mastery_Overlord_BuffImmuned(eventArg, mastery, owner, ds)
	if eventArg.Reason ~= 'Mastery_ToughSpirit' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffImmuned_Self');
	InsertBuffActions(actions, owner, owner, mastery.ThirdBuff.name, 1, true);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 버프를 줌 [BuffGived]
----------------------------------------------------------------------------
-- 빛보다 빠른 주먹 / 물실호기
function Mastery_SharedBuffAppliedSet(eventArg, mastery, owner, ds)
	if not eventArg.AbilityBuff
		or eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	local buffGivedSet = GetInstantProperty(owner, mastery.name) or {};
	buffGivedSet[GetObjKey(eventArg.Unit)] = true;
	SetInstantProperty(owner, mastery.name, buffGivedSet);
end
--------------------------------------------------------------------------------
-- 조사 상호 작용 [InvestigationOccured]
----------------------------------------------------------------------------
-- 야사 알
function Mastery_HatchedObjectYasha_InvestigationOccured(eventArg, mastery, owner, ds)
	local actions = {};
	
	local itemProb = 10;
	-- 확률 보정
	local mission = GetMission(owner);
	local company = GetCompany(eventArg.Detective);
	if not company then
		return;
	end
	local prevCount = GetCompanyInstantProperty(company, 'Lockpick_UnderWaterWayCount') or 0;
	local units = GetAllUnit(mission);
	local remainCount = table.count(units, function(o) return o.name == owner.name end);
	if remainCount == 1 and prevCount == 0 then
		itemProb = 100;
	end
	if RandomTest(itemProb) then
		local giveItem = Result_GiveItem(eventArg.Detective, 'Lockpick_UnderWaterWay', 1);
		table.append(actions, { GiveItemWithInstantEquipDialog(ds, giveItem, eventArg.Detective) });
		SetCompanyInstantProperty(company, 'Lockpick_UnderWaterWayCount', prevCount + 1);	
	end
	
	-- 남은 야샤 소환, 버프 해제
	local buff = GetBuff(owner, 'HatchedObjectYasha');
	if buff and buff.Life > 0 then
		table.append(actions, { Buff_HatchedObjectYasha_DoHatching(ds, owner, buff.Life) });
		InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.Lv);
	end
	
	-- 오브젝트 교체
	local particleId = ds:PlayParticle(GetObjKey(owner), '_BOTTOM_', 'Particles/Dandylion/Explosion_Egg', 2, false, false, true);
	local moveCam = ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	local lookPos = GetPosition(owner);
	local enableId = ds:EnableIf('TestPositionIsVisible', lookPos);
	ds:Connect(moveCam, enableId, -1);
	ds:SetCommandLayer(enableId, game.DirectingCommand.CM_SECONDARY);
	local delay = ds:Sleep(0);
	ds:SetCommandLayer(delay, game.DirectingCommand.CM_SECONDARY);
	ds:Connect(delay, enableId, 0);
	ds:Connect(particleId, enableId, 0);
	table.insert(actions, Result_ChangeTeam(owner, '_dummy', false));
	table.insert(actions, Result_DestroyObject(owner, false, true));	
	local destroyedMonType = GetInstantProperty(owner, 'DestroyedMonsterType');
	if destroyedMonType then
		local direction = GetDirection(owner);
		local clearDying = Result_ClearDyingObjects();
		clearDying._ref = delay;
		clearDying._ref_offset = 0;
		table.insert(actions, clearDying);
		local destroy = Result_CreateMonster(GenerateUnnamedObjKey(GetMission(owner)), destroyedMonType, GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		destroy._ref = delay;
		destroy._ref_offset = 0;
		table.insert(actions, destroy);
	end

	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 어빌리티 사용 가능 횟수 증가(회복) [AbilityUseCountRestored]
----------------------------------------------------------------------------
-- 기계장인 가죽 자켓
function Mastery_Jacket_Mechanic_Set_AbilityUseCountRestored(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or not IsProtocolAbility(eventArg.Ability)
		or eventArg.AddAmount <= 0 then
		return;
	end
	mastery.CountChecker = mastery.CountChecker + 1;
end
----------------------------------------------------
-- 모방 공격, 모방 방어
function Mastery_ImitationBlah_Resetter(eventArg, mastery, owner, ds)
	mastery.CountChecker = 0;
	SetInstantProperty(owner, mastery.name, nil);
	local actions = {};
	AddActionImitationMapSyncronize(actions, owner, mastery);
	table.insert(actions, Result_BuffPropertyUpdated('Lv', 0, owner, mastery.name, true, true, nil, true));
	return unpack(actions);
end
function Mastery_ImitationBlah_Adder(eventArg, mastery, owner, ds)
	if eventArg.EventType == 'MasteryInitialized' and (owner ~= eventArg.Unit or eventArg.Mastery ~= mastery) then
		return;
	end
	local actions = {Result_AddBuff(owner, owner, mastery.name, 0, nil, true)};
	AddActionImitationMapSyncronize(actions, owner, mastery);
	return unpack(actions);
end
function Mastery_ImitationBlah_Activator(eventArg, mastery, owner, ds)
	return Result_BuffPropertyUpdated('Stack', true, owner, mastery.name, true, true, false, true);
end
function Mastery_ImitationBlah_Passiver(eventArg, mastery, owner, ds)
	return Result_BuffPropertyUpdated('Stack', false, owner, mastery.name, true, true, false, true);
end
function Mastery_ImitationBlah_Remover(eventArg, mastery, owner, ds)
	return Result_RemoveBuff(owner, mastery.name, true);
end
function AddActionImitationBlahShow(actions, owner, mastery)
	local limit = 0;
	if mastery.name == 'ImitationAttack' then
		limit = GetImitationAttackLimit(owner, mastery);
	elseif mastery.name == 'ImitationDefence' then
		limit = GetImitationDefenceLimit(owner, mastery);
	end
	table.insert(actions, Result_BuffPropertyUpdated('Lv', limit - mastery.CountChecker, owner, mastery.name, true, true, false, true));
end


-- 참회
---@param eventArg buffRemovedEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Repentance_BuffRemoved_Self(eventArg, mastery, owner, ds)
	if eventArg.BuffName ~= mastery.Buff.name then
		return;
	end
	-- 버프가 새로 걸리는 경우에는 발동하지 않음
	if eventArg.BuffAdded then
		return;
	end
	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	af:InsertRandomBuff(owner, owner, 'Buff_Positive', 1, function(b) return b.SubType == 'Mental' end);
	return af:UnpackActions('BuffRemoved_Self');
end


-- 거포
---@param eventArg friendlyMachineHasJoinedEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_GreatCannon_FriendlyMachineHasJoined(eventArg, mastery, owner, ds)
	-- 기계 소환도 아니고, 제어권 탈취도 아니면 무시
	local isSummoned = GetObjKey(owner) == GetInstantProperty(eventArg.Machine, 'SummonMaster');
	local isHacked = Set.new(GetInstantProperty(owner, 'ControlTakingOverTargets') or {})[GetObjKey(eventArg.Machine)];
	if not isSummoned and not isHacked then
		return;
	end

	local reinforceMastery = mastery.Mastery;
	return Result_UpdateMastery(eventArg.Machine, reinforceMastery.name, 1);
end


-- 거포
---@param eventArg friendlyMachineAboutToLeaveEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_GreatCannon_FriendlyMachineAboutToLeave(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= eventArg.MasterKey then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	return Result_UpdateMastery(eventArg.Machine, reinforceMastery.name, -1);
end


-- 정밀 조정
---@param eventArg friendlyMachineHasJoinedEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_FineTuning_FriendlyMachineHasJoined(eventArg, mastery, owner, ds)
	-- 기계 소환도 아니고, 제어권 탈취도 아니면 무시
	local isSummoned = GetObjKey(owner) == GetInstantProperty(eventArg.Machine, 'SummonMaster');
	local isHacked = Set.new(GetInstantProperty(owner, 'ControlTakingOverTargets') or {})[GetObjKey(eventArg.Machine)];
	if not isSummoned and not isHacked then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	return Result_UpdateMastery(eventArg.Machine, reinforceMastery.name, 1);
end

-- 정밀 조정
---@param eventArg friendlyMachineAboutToLeaveEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_FineTuning_FriendlyMachineAboutToLeave(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= eventArg.MasterKey then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	return Result_UpdateMastery(eventArg.Machine, reinforceMastery.name, -1);
end


-- 능숙한 조종
---@param eventArg friendlyMachineHasJoinedEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_SkillfulContorolMachine_FriendlyMachineHasJoined(eventArg, mastery, owner, ds)
	-- 기계 소환도 아니고, 제어권 탈취도 아니면 무시
	local isSummoned = GetObjKey(owner) == GetInstantProperty(eventArg.Machine, 'SummonMaster');
	local isHacked = Set.new(GetInstantProperty(owner, 'ControlTakingOverTargets') or {})[GetObjKey(eventArg.Machine)];
	if not isSummoned and not isHacked then
		return;
	end
	return Result_UpdateInstantProperty(eventArg.Machine, mastery.name, GetObjKey(owner));
end


-- 능숙한 조종
---@param eventArg friendlyMachineAboutToLeaveEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_SkillfulContorolMachine_FriendlyMachineAboutToLeave(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= eventArg.MasterKey then
		return;
	end
	return Result_UpdateInstantProperty(eventArg.Machine, mastery.name, nil);
end


-- 충격 전환
---@param eventArg unitTakeDamageEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Module_ShockConversion_UnitTakeDamage_Self(eventArg, mastery, owner, ds)
	-- 조건 처리
	if eventArg.Damage <= 0
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability' then
		return;
	end

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	
	-- 기능 구현
	af:AddSP(owner, mastery.ApplyAmount, true);
	af:AddAction(Result_FireWorldEvent('ShockConversionOccurred', {Invoker = owner}, owner));

	return af:UnpackActions('UnitTakeDamage_Self')
end


-- 개량된 에너지 충전
---@param eventArg any
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Module_ShockConversionCharging_ShockConversionOccurred(eventArg, mastery, owner, ds)
	-- 조건 처리
	local ability = FindAbility(owner, 'Charging_Machine', true);
	if eventArg.Invoker ~= owner
		or not ability 
		or ability.UseCount > 0 then
		return;
	end

	local cnt = GetInstantProperty(owner, mastery.name) or 0;
	cnt = cnt + 1;
	if cnt < 10 then
		SetInstantProperty(owner, mastery.name, cnt);
		return;
	end

	SetInstantProperty(owner, mastery.name, 0);

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	
	-- 기능 구현
	af:AddAction(Result_AbilityPropertyUpdated('UseCount', 1, owner, 'Charging_Machine', true));

	return af:UnpackActions('ShockConversionOccurred')
end


-- 개량된 충격 흡수
---@param eventArg any
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Module_ShockAbsorberConversion_ShockConversionOccurred(eventArg, mastery, owner, ds)
	if eventArg.Invoker ~= owner then
		return;
	end

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	
	-- 기능 구현
	af:AddSP(owner, mastery.ApplyAmount, true);

	return af:UnpackActions('ShockConversionOccurred')
end


-- 무한검
---@param eventArg missionBeginEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_UnlimitedBlade_MissionBegin(eventArg, mastery, owner, ds)
	-- 조건 처리

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	
	-- 기능 구현
	af:InsertBuff(owner, owner, mastery.Buff.name, 1);

	return af:UnpackActions('MissionBegin')
end


-- 광학 위장 공격
---@param eventArg preAbilityUsingEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Module_SilentAttack_PreAbilityUsing_Self(eventArg, mastery, owner, ds)
	if HasBuff(owner, mastery.Buff.name) then
		mastery.CountChecker = 1;
	else
		mastery.CountChecker = 0;
	end
end


-- 고성능 무기 출력 전환
---@param eventArg preAbilityUsingEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Module_WeaponPowerConverterEnhanced_PreAbilityUsing_Self(eventArg, mastery, owner, ds)
	if owner.Overcharge > 0 then
		mastery.CountChecker = 1;
	else
		mastery.CountChecker = 0;
	end
end


-- 삶에 대한 집착
---@param eventArg unitDeadEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_RunAwayFromDeath_UnitDead(eventArg, mastery, owner, ds)
	-- 조건 처리
	if not IsTeamOrAlly(owner, eventArg.Unit)
		or eventArg.Unit == owner
		or not IsInSight(owner, eventArg.Unit, true) then
		return;
	end

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	
	-- 기능 구현
	af:ApplyAct(owner, owner, -mastery.ApplyAmount, 'Friendly');

	return af:UnpackActions('UnitDead')
end


-- 승부욕
---@param eventArg buffAddedEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_DesireForWinning_BuffAdded_Self(eventArg, mastery, owner, ds)
	-- 조건 처리
	if eventArg.Unit ~= owner 
		or eventArg.Buff.Type ~= 'Buff' 
		or eventArg.Buff.SubType ~= 'Mental' 
		or not eventArg.Buff.IsTurnShow then
		return;
	end

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	
	-- 기능 구현
	local addTurn = mastery.ApplyAmount;
	
	-- 열혈 싸움꾼
	af:AddSynergyMasteryAction(owner, 'PassionateFighter', function(sm)
		addTurn = addTurn + sm.ApplyAmount4;
	end);

	af:AddAction(Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, owner, eventArg.Buff.name, false, true));
	af:AddAction(Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, owner, eventArg.Buff.name, true, true));

	return af:UnpackActions('BuffAdded_Self')
end


-- 붉은모래 손목 고리
---@param eventArg unitTakeDamageEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Bracelet_MunggoEnhanced_Legend_UnitTakeDamage_Self(eventArg, mastery, owner, ds)
	-- 조건 처리
	if eventArg.Damage <= owner.MaxHP * (mastery.ApplyAmount / 100) then
		return;
	end
	-- 반짝이는 충격 보호대, 충격장 발동으로 데미지가 50% 컷이 될 때, 최대 체력이 홀수인 경우 math.ceil 처리로 인해 위의 조건 처리를 넘어갈 수 있으므로 추가 처리
	local damageFlag = SafeIndex(eventArg, 'DamageInfo', 'Flag');
	if SafeIndex(damageFlag, 'Amulet_AniDamage') or SafeIndex(damageFlag, 'ImpulseFields') then
		if eventArg.Damage <= math.ceil(owner.MaxHP * (mastery.ApplyAmount / 100)) then
			return;
		end
	end

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	
	-- 기능 구현
	af:InsertBuff(owner, owner, mastery.Buff.name, 1);

	return af:UnpackActions('UnitTakeDamage_Self');
end


-- 휴대용 항동결 수액
---@param eventArg masteryInitializedEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Amulet_Munggo_AntiFreezing_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffName = mastery.SubBuff.name;
	local buffLv = mastery.ApplyAmount;

	local actions = {};
	InsertBuffActions(actions, owner, owner, buffName, buffLv, true, nil, nil, {Type = mastery.name});
	return unpack(actions);
end


-- 변형된 항동결 수액
---@param eventArg masteryInitializedEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Amulet_Munggo_AntiFreezing_Legend_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffName = mastery.SubBuff.name;
	local buffLv = mastery.ApplyAmount;

	local actions = {};
	InsertBuffActions(actions, owner, owner, buffName, buffLv, true, nil, nil, {Type = mastery.name});
	return unpack(actions);
end


-- 떨어지는 고드름
---@param eventArg boltInvokedEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_FallingIcicles_BoltInvoked(eventArg, mastery, owner, ds)
	-- 조건 처리
	if eventArg.Unit ~= owner
		or eventArg.Mastery ~= 'IceBolt'
		or eventArg.Damage <= 0 then
		return;
	end

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	
	-- 기능 구현
	af:InsertBuff(owner, eventArg.Target, mastery.SubBuff.name, 1);

	return af:UnpackActions('BoltInvoked');
end


-- 천벌
---@param eventArg unitKilledEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_HeavenPunishment_UnitKilled_Self(eventArg, mastery, owner, ds)
	-- 조건 처리

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	
	-- 기능 구현
	af:ApplyAct(owner, owner, -mastery.ApplyAmount, 'Friendly');
	af:AddAbilityCool(owner, -mastery.ApplyAmount2, nil);

	return af:UnpackActions('UnitKilled_Self')
end


-- 전염병
---@param eventArg buffAddedEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Epidemic_BuffAdded(eventArg, mastery, owner, ds)
	-- 조건 처리
	if GetBuffGiver(eventArg.Buff) ~= owner 
		or eventArg.Buff.Group ~= mastery.BuffGroup.name
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.Invoker == mastery then	-- 자기가 건게 재차 돌지 않도록
		return;
	end

	local af = MasteryActionFactory.new(ds);
	af:AddActivator(mastery, owner);
	
	-- 기능 구현
	local nearEnemies = table.filter(GetNearObject(eventArg.Unit, 1.4), function(o)
		return o ~= eventArg.Unit and IsEnemy(owner, o) 
	end);
	for _, e in ipairs(nearEnemies) do
		af:InsertBuff(owner, e, eventArg.BuffName, eventArg.BuffLevel, nil, nil, mastery);
	end

	return af:UnpackActions('BuffAdded');
end


-- 자동 회피 기동
---@param eventArg actionDelimiterEventArg
---@param mastery class_Mastery
---@param owner unit
---@param ds DirectingScripter
function Mastery_Module_EscapeMove_ActionDelimiter(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end

------------------------------------------------------------
-- [MOD] 个人主义(Individualism)关联：公司天赋 + 功能性增益 + 预热BUFF
-- 由 MODWORK 工作区生成，TroubleTool 加载 Data 后生效
------------------------------------------------------------
--- 可享受个人主义的单位：与"单天赋解锁附加天赋效果"的分发完全一致。
--- 直接复用全局 Xzfj_IsPlayerSideUnit（shared_mastery.lua）的判定：
---   * 同队(Team)/友善(Ally)：享受；
---   * 属于玩家队伍 / 被标记为用户成员 / 驯服者属于我方的动物或特殊单位
---     （如 Tima 这类野兽，关卡关系表对 player 为 enemy/None，即使加入我方
---     GetRelation 仍非 Team/Ally）：享受；
---   * 中立(None)与敌方(Enemy)：被排除，不享受。
--- 这样个人主义/预热/先制反击 与 附加天赋效果 的受益范围严格一致，
--- 避免出现"附加天赋效果已发、个人主义却没发"的分发不一致缺陷。
--- 注意：旧版 shared_mastery（XZJF_Legacy 系列）不含 Xzfj_IsPlayerSideUnit，
--- 用 pcall 包裹并退回 GetRelation 判定，防止 nil 崩溃。
local function Xzfj_IsBeneficiary(unit, giver)
	if not unit or not unit.HP or unit.HP <= 0 or unit.Untargetable then
		return false;
	end
	if unit.Obstacle then
		return false;
	end
	if unit.Race and unit.Race.name == 'Object' then
		return false;
	end
	local ok, isPlayerSide = pcall(Xzfj_IsPlayerSideUnit, unit);
	if ok then
		return isPlayerSide;
	end
	-- 兜底（不含 Xzfj_IsPlayerSideUnit 的旧版场景）
	local rel = GetRelation(giver, unit);
	return rel == 'Team' or rel == 'Ally';
end

--- 个人主义附带的其它公司/实用天赋（战斗中额外加强；跳过不存在的类名）
local XZFJ_BONUS_MASTERIES = {
	-- 公司天赋
	'Scavenger', 'CustomerSatisfaction', 'SenseOfBelonging', 'Pride',
	'Individualism', 'Expertise', 'HardFight', 'SafetyFirst', 'FastWork',
	-- 便利/收益类
	'Learning', 'Understanding', 'Insight', 'TreasureHunter',
	'AliBaba', 'Frankness', 'Yearning', 'PangOfConscience',
	'Supporter', 'Immersion', 'PositiveMind', 'TreasureIsland',
	'TreasureOfKing', 'Informant', 'MaterialCollector', 'GoldenCity',
	'LegendaryServant', 'Expert', 'LargeTopPocket', 'LargeBottomPocket',
	'GreatSupporter', 'Sortilege',
}

--- 给友方（同队+友善+中立友善）上/刷新 WarmUp
local function Xzfj_ApplyTeamWarmUp(actions, giver, mission)
	mission = mission or GetMission(giver)
	for _, unit in ipairs(GetAllUnit(mission) or {}) do
		if Xzfj_IsBeneficiary(unit, giver) then
			local buff = GetBuff(unit, 'WarmUp')
			if buff then
				table.insert(actions, Result_BuffPropertyUpdated('Life', buff.Turn, unit, 'WarmUp', true))
			else
				InsertBuffActions(actions, giver, unit, 'WarmUp', 1, true)
			end
		end
	end
end

--- 授予未拥有的附带天赋（跳过不存在的类名）
local function Xzfj_ApplyBonusMasteries(actions, unit, ds)
	if not unit then
		return
	end
	local masteryTable = GetMastery(unit)
	local masteryClsList = GetClassList('Mastery')
	for _, masteryName in ipairs(XZFJ_BONUS_MASTERIES) do
		local masteryCls = masteryClsList and masteryClsList[masteryName]
		if masteryCls and not GetMasteryMastered(masteryTable, masteryName) then
			table.insert(actions, Result_UpdateMastery(unit, masteryName, 1))
			if ds then
				MasteryActivatedHelper(ds, masteryCls, unit, 'Added')
			end
		end
	end
end

local function Xzfj_ApplyTeamBonusMasteries(actions, giver, ds, mission)
	mission = mission or GetMission(giver)
	for _, unit in ipairs(GetAllUnit(mission) or {}) do
		if Xzfj_IsBeneficiary(unit, giver) then
			Xzfj_ApplyBonusMasteries(actions, unit, ds)
		end
	end
end

--- 收回单个单位身上的个人主义/预热效果（敌方行动时调用）。
--- 移除：
---   * WarmUp buff（敌人永远不会自带）；
---   * Individualism 天赋本体（移除后引擎自动取消其连带的公司/实用天赋，
---     因为 GetMastery 中 Individualism 不存在后，这些天赋不再被"个人主义
---     已装备"的判定支撑，K1 等级附加效果也会因 Xzfj_IsPlayerSideUnit
---     返回 false 而被 GetSetMastery 实时拒绝）。
---@param actions table
---@param unit unit
local function Xzfj_RevokeUnitBenefits(actions, unit)
	if not unit then
		return
	end
	if GetBuff(unit, 'WarmUp') then
		table.insert(actions, Result_RemoveBuff(unit, 'WarmUp'))
	end
	local masteryTable = GetMastery(unit)
	local masteryClsList = GetClassList('Mastery')
	if GetMasteryMastered(masteryTable, 'Individualism') then
		table.insert(actions, Result_UpdateMastery(unit, 'Individualism', -1))
	end
	-- 顺带收回个人主义附带的公司/实用天赋（这些原本只有我方单位会被授予，
	-- 敌人身上不应残留；移除时跳过不存在的类名）
	for _, masteryName in ipairs(XZFJ_BONUS_MASTERIES) do
		local masteryCls = masteryClsList and masteryClsList[masteryName]
		if masteryCls and GetMasteryMastered(masteryTable, masteryName) then
			table.insert(actions, Result_UpdateMastery(unit, masteryName, -1))
		end
	end
end

--- 给单个单位补发 WarmUp + Individualism + 附带公司/实用天赋（我方单位行动时调用）
---@param actions table
---@param unit unit
---@param giver unit
---@param ds any
local function Xzfj_EnsureUnitBenefits(actions, unit, giver, ds)
	if not unit then
		return
	end
	local buff = GetBuff(unit, 'WarmUp')
	if buff then
		table.insert(actions, Result_BuffPropertyUpdated('Life', buff.Turn, unit, 'WarmUp', true))
	else
		InsertBuffActions(actions, giver, unit, 'WarmUp', 1, true)
	end
	Xzfj_ApplyBonusMasteries(actions, unit, ds)
end

--- 开局：全员 WarmUp + 附带公司/实用天赋
function Mastery_Xianzhifanji_MissionBegin(eventArg, mastery, owner, ds)
	local actions = {}
	Xzfj_ApplyTeamWarmUp(actions, owner)
	Xzfj_ApplyTeamBonusMasteries(actions, owner, ds)
	return unpack(actions)
end

--- 单位行动（全局 UnitTurnStart）：对行动单位本人做精确的补发/收回。
--- 无论地图处于什么阶段（开场演出、正式战斗、读档后、单位中途登场/变队），
--- 只要一个单位开始行动：
---   * 若该单位受我方控制（Xzfj_IsPlayerSideUnit 为真）→ 本人补发
---     WarmUp + Individualism + 附带天赋（已有则刷新，没有则添加）；
---   * 否则（敌方/中立）→ 本人收回 WarmUp + Individualism + 附带天赋，
---     确保敌人永远没有这些效果。
--- 这样彻底摆脱对 MissionBegin/演出阶段初始化时机的依赖。
function Mastery_Xianzhifanji_UnitTurnStart(eventArg, mastery, owner, ds)
	if not eventArg or not eventArg.Unit then
		return
	end
	local unit = eventArg.Unit
	if not unit.HP or unit.HP <= 0 then
		return
	end
	if unit.Obstacle then
		return
	end
	if unit.Race and unit.Race.name == 'Object' then
		return
	end
	local actions = {}
	if Xzfj_IsPlayerSideUnit(unit) then
		Xzfj_EnsureUnitBenefits(actions, unit, owner, ds)
	else
		Xzfj_RevokeUnitBenefits(actions, unit)
	end
	return unpack(actions)
end
