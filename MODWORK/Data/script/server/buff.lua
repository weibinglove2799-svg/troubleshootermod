--- 버프 관련 공용 서버사이드 함수들 ---
--------------------------------
local BuffDamageComposer = nil;
function GetModifyBuffDamage(giver, receiver, damage, damageSubType)
	if BuffDamageComposer == nil then
		BuffDamageComposer = BattleFormulaComposer.new('Base * (1 + (Mul - MinusMul)/ 100) + Add', {'Base', 'Mul', 'MinusMul', 'Add'});
	end
	local composer = BuffDamageComposer:Clone();
	composer:AddDecompData('Base', damage);
	return composer:ComposeFormula(), composer:ComposeInfoTable();
end
function CalculatedProperty_BuffCustomEventHandler(self)
	local eventHandlers = {};
	
	if self.UseSelfDischarger then
		table.insert(eventHandlers, {Event='UnitTurnStart_Self', Script=Buff_Turn_Start_SelfDischarge, Order=--[[최우선처리]]0});
	end

	if self.UseHPModifier then
		local order = self.HPChangeHitType == 'Heal' and 1 or 2;
		if self.HPModifyTiming == 'Start' then
			table.insert(eventHandlers, {Event='UnitTurnStart_Self', Script=Buff_Apply_HPModifier('Unit'), Order=order});
		elseif self.HPModifyTiming == 'End' then
			table.insert(eventHandlers, {Event='UnitTurnEnd_Self', Script=Buff_Apply_HPModifier('Unit'), Order=order});
			table.insert(eventHandlers, {Event='BuffRemoved_Self', Script=Buff_Apply_HPModifier_LastApply, Order=order});
		end
	end
	
	-- Discharge 공용	
	if self.DischargeOnOverchargeRelease then
		table.insert(eventHandlers, {Event='OverchargeEnded', Script=Buff_OverchargeEnded_DischargeOnOverchargeRelease, Order=1});
	end
	if self.DischargeOnNoAttackableTarget then
		table.insert(eventHandlers, {Event='UnitTurnStart_Self', Script=Buff_UnitTurnStart_DischargeOnNoAttackableTarget, Order=1});
	end
	if self.DischargeOnAttack then
		table.insert(eventHandlers, {Event='AbilityUsed_Self', Script=Buff_AbilityUsed_DischargeOnAttack, Order=2});
	end

	if self.DischargeOnHit then
		table.insert(eventHandlers, {Event='UnitTakeDamage_Self', Script=Buff_TakeDamage_DischargeOnHit, Order=2});
	end
	
	if self.DischargeOnMove then
		-- Order에 별 의미 없음
		table.insert(eventHandlers, {Event='UnitMoved_Self', Script=Buff_UnitMoved_DischargeOnMove, Order=5});
	end
	if self.DischargeOnAbility then
		-- Order에 별 의미 없음
		table.insert(eventHandlers, {Event='PreAbilityUsing_Self', Script=Buff_PreAbilityUsing_DischargeOnAbility, Order=5});
	end
	if self.DischargeOnUnconscious then
		table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Buff_BuffAdded_DischargeOnUnconscious, Order=2});
	end
	
	if self.UseActionController then
		table.insert(eventHandlers, {Event='UnitTurnStart_Self', Script=Buff_Turn_Start_ActionController, Order=1});
	end
	
	if self.Immortal then
		table.insert(eventHandlers, {Event='UnitTakeDamage_Self', Script=Buff_Immortal_TakeDamage, Order=0});
	end

	if self.UseAddedMessage then
		table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Buff_Added_Message, Order = 1});
	end
	
	if self.UseForwardTurnTest then
		table.insert(eventHandlers, {Event='UnitTurnStart_Self', Script='Buff_Turn_Start_Forward_Test', Order=3});
	end
	-- 매 턴 시작 시, 추가 기력 소모 상태 해제.
	if self.UseTurnStartCostEater then
		table.insert(eventHandlers, {Event='UnitTurnStart_Self', Script='Buff_CostEater_UnitTurnStart', Order=1});
	end
	-- 매 턴 시작 시, 추가 SP 소모 상태 해제.
	if self.UseTurnStartSPEater then
		table.insert(eventHandlers, {Event='UnitTurnStart_Self', Script='Buff_SPEater_UnitTurnStart', Order=1});
	end
	-- 완전 엄폐물 턴 종료.
	if self.IsCoverableObject then
		table.insert(eventHandlers, {Event='UnitTurnStart_Self', Script='Buff_CoverableObject_UnitTurnStarted', Order=1});
	end
	-- 대미지 반사.
	if self.UseReflectDamage then
		table.insert(eventHandlers, {Event='AbilityAffected', Script='Buff_ReflectDamage_AbilityAffected', Order=1});
	end

	if self.AuraBuff ~= 'None' then
		table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Buff_CommonAura_BuffAdded, Order = 2});
		table.insert(eventHandlers, {Event='UnitCreated', Script=Buff_CommonAura_UnitCreated, Order = 2});
		table.insert(eventHandlers, {Event='InvalidateAuraTarget', Script=Buff_CommonAura_InvalidateAuraTarget, Order = 1});
		if self.AuraType == 'InRange' then
			table.insert(eventHandlers, {Event='BuffRemoved_Self', Script=Buff_CommonAura_BuffRemoved_InRange, Order = 2});
			table.insert(eventHandlers, {Event='UnitMoved_Self', Script=Buff_CommonAura_UnitMoved_InRange_Self, Order = 2});
			table.insert(eventHandlers, {Event='UnitMoved', Script=Buff_CommonAura_UnitMoved_InRange_Others, Order = 2});
			table.insert(eventHandlers, {Event='UnitTeamChanged', Script=Buff_CommonAura_UnitTeamChanged_InRange, Order = 2});
			table.insert(eventHandlers, {Event='UnitPositionChanged', Script=Buff_CommonAura_UnitPositionChanged_InRange, Order = 2});
			table.insert(eventHandlers, {Event='UnitPositionChanged_Self', Script=Buff_CommonAura_UnitPositionChanged_Self_InRange, Order = 2});
			table.insert(eventHandlers, {Event='UnitDead_Self', Script=Buff_CommonAura_UnitDead_InRange_Self, Order = 2});
			table.insert(eventHandlers, {Event='UnitBeingExcluded', Script=Buff_CommonAura_UnitDead_InRange_Self, Order = 2});
			table.insert(eventHandlers, {Event='UnitResurrect_Self', Script=Buff_CommonAura_UnitResurrect_InRange_Self, Order = 2});
			table.insert(eventHandlers, {Event='UnitDead', Script=Buff_CommonAura_UnitDead_InRange, Order = 2});
			table.insert(eventHandlers, {Event='UnitBeingExcluded', Script=Buff_CommonAura_UnitDead_InRange, Order = 2});
			table.insert(eventHandlers, {Event='UnitResurrect', Script=Buff_CommonAura_UnitResurrect_InRange, Order = 2});
			if self.AuraRange == 'Sight' then
				table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Buff_CommonAura_SightRangeChanged, Order=1});
				table.insert(eventHandlers, {Event='BuffRemoved_Self', Script=Buff_CommonAura_SightRangeChanged, Order=1});
			end
		elseif self.AuraType == 'ThroughRange' then
			table.insert(eventHandlers, {Event='BuffRemoved_Self', Script= Buff_CommonAura_BuffRemoved_ThroughRange, Order = 2});
			table.insert(eventHandlers, {Event='UnitMoveStarted', Script=Buff_CommonAura_UnitMoveStarted_ThroughRange, Order = 2});
			table.insert(eventHandlers, {Event='UnitMovedSingleStep', Script=Buff_CommonAura_UnitMovedSingleStep_ThroughRange, Order = 0});
			table.insert(eventHandlers, {Event='UnitMoved', Script=Buff_CommonAura_UnitMoved_ThroughRange, Order = 2});
			table.insert(eventHandlers, {Event='UnitPositionChanged', Script=Buff_CommonAura_UnitPositionChanged_ThroughRange, Order = 2});
		else
			LogAndPrint('AuraType is invalid - self.name : ', self.name, ', self.AuraType : ', self.AuraType);
		end
	end
	
	if self.Brainwashing then
		table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Buff_Added_Brainwashing, Order=1});
		table.insert(eventHandlers, {Event='BuffRemoved_Self', Script=Buff_Removed_Brainwashing, Order=1});
		table.insert(eventHandlers, {Event='UnitDead_Self', Script=Buff_UnitResurrect_Brainwashing, Order=0});
		if self.BrainwashingTeamFollowUp then
			table.insert(eventHandlers, {Event='UnitTeamChanged', Script=Buff_UnitTeamChanged_Brainwashing, Order=0});
		end
	end
	
	if self.AbilityHolder then
		table.insert(eventHandlers, {Event='MissionReinitialized', Script=Buff_AbilityHolder_MissionReinitialized, Order=1});
		table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Buff_AbilityHolder_Added, Order=1});
		table.insert(eventHandlers, {Event='BuffRemoved_Self', Script=Buff_AbilityHolder_Removed, Order=1});
		table.insert(eventHandlers, {Event='UnitDead_Self', Script=Buff_AbilityHolder_UnitDead, Order=1});
		table.insert(eventHandlers, {Event='UnitDead', Script=Buff_AbilityHolder_UnitDead_Virtual, Order=1});
		table.insert(eventHandlers, {Event='UnitResurrect_Self', Script=Buff_AbilityHolder_UnitResurrect, Order=1});
	end
	
	if self.MasterFieldAffector ~= 'None' then
		table.insert(eventHandlers, {Event='UnitTurnEnd_Self', Script=Buff_FieldEffectSlave_UnitTurnEnd(self.MasterFieldAffector), Order=1});
	end
	
	if self.IsAuraSlave then
		table.insert(eventHandlers, {Event='InvalidateAuraTarget_Self', Script=Buff_AuraSlave_InvalidateAuraTarget, Order=1});
	end
	
	if self.ModifyAbility ~= 'None' then
		table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Buff_ModifyAbility_BuffAdded, Order=1});
		table.insert(eventHandlers, {Event='BuffRemoved_Self', Script=Buff_ModifyAbility_BuffRemoved, Order=1});
	end
	
	if not self.Coverable or self.FriendsOfAll or self.EnemiesOfAll then
		table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Buff_Common_InvalidateAuraTarget, Order=1});
		table.insert(eventHandlers, {Event='BuffRemoved_Self', Script=Buff_Common_InvalidateAuraTarget, Order=1});	
	end

	local immuneGroups = GetWithoutError(self, 'ImmuneDebuff_BuffGroup');
	if immuneGroups and #immuneGroups > 0 then
		table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Buff_ImmuneDebuff_BuffGroup_BuffAdded, Order = 1});
	end

	return eventHandlers;
end

function FunctionProperty_BuffGetSelfDischargeRate(buff, owner)
	-- 디버프만 적용된다.
	local result = 0;
	local denominator = GetBuffGetSelfDischargeRate(owner.Lv);
	if buff.Type ~= 'Debuff' then
		return result, denominator;
	end
	-- 버프 첫턴 보정.
	-- 몬스터 보정.
	if buff.Age == 0 then
		if GetCompany(owner) then
			denominator = denominator;
		else
			denominator = denominator * 2 * owner.Grade.DeBuffRatio;
		end
	elseif buff.Age == 1 then
		if GetCompany(owner) then
			denominator = denominator * 0.75;
		else
			denominator = denominator * owner.Grade.DeBuffRatio;
		end
	elseif buff.Age >= 2 then
		if GetCompany(owner) then
			denominator = denominator * 0.5;
		end	
	end
	denominator = math.max(1, denominator);
	
	-- 속성 값 오류면 안풀린다. ( 에러 )
	local targetRegistance = buff.BreakType;
	if not SafeIndex(owner, targetRegistance)  then
		return result, denominator;
	end

	-- 1. 분자는 다음과 같다.
	result = owner[targetRegistance];
	return result, denominator;
end
function FunctionProperty_BuffGetSelfDischargeRate_Malfunction(buff, owner)
	return 5, 100;
end
function AddBuffDamageChat(ds, object, buff, damage)
	if buff == nil or buff.name == nil then
		LogAndPrint('[DataError] AddBuffDamageChat Buff is invalid - buff:', buff, ', object:', GetUnitDebugName(object), ', damage:', damage);
		Traceback();
		return;
	end
	local buffKey = 'Buff';
	if buff.Type == 'Debuff' then
		buffKey = 'Debuff';
	end
	local msg = 'BuffDamage';
	local damageAmount = damage;
	if damage < 0 then
		msg = 'BuffHeal';
		damageAmount = -damage;
	end
	ds:AddRelationMissionChat(buffKey, msg, { ObjectKey = GetObjKey(object), Buff = buff.name, Damage = damageAmount });
end
function AddBuffEventChat(ds, object, buff)
	if buff == nil or buff.name == nil then
		LogAndPrint('[DataError] AddBuffEventChat Buff is invalid - buff:', buff, ', object:', GetUnitDebugName(object));
		Traceback();
		return;
	end
	local buffKey = 'Buff';
	if buff.Type == 'Debuff' then
		buffKey = 'Debuff';
	end
	local msg = 'BuffEvent';
	ds:AddRelationMissionChat(buffKey, msg, { ObjectKey = GetObjKey(object), Buff = buff.name });
end
----- 공용 이벤트 핸들러 ------
---------------------------
function Buff_Apply_HPModifier(targetKey)
	return function(eventArg, buff, owner, giver, ds)
		if eventArg[targetKey] ~= owner then
			return;
		end
		return Buff_Apply_HPModifier_Internal(buff, owner, giver, ds);
	end;
end
function Buff_Apply_HPModifier_LastApply(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff or buff.Life > 0 then
		return;
	end
	
	return Buff_Apply_HPModifier_Internal(buff, owner, giver, ds);
end
function Buff_Apply_HPModifier_Internal(buff, owner, giver, ds)
	local hpChangeValue = buff:HPChangeFunction(owner);
	if hpChangeValue == nil then -- 뭔가의 이유로 데미지를 주지 않는 경우
		return;
	end
	hpChangeValue = math.floor(hpChangeValue);
	if owner.HP > 0 and owner.HP + hpChangeValue <= 1 and buff.NoKill then	-- 사망에 이르게 하는지 여부체크
		hpChangeValue = 1 - owner.HP;	-- 데미지는 마이너스 값이다. 착각하지 말자
	end

	local curDamage = GetModifyBuffDamage(giver, owner, -hpChangeValue, buff.HPChangeHitType);
	
	local damage = Result_Damage(curDamage, 'Normal', 'Hit', owner, owner, 'Buff', 'Etc', buff);	-- 버프에 의한 체력 변화는 스스로 주는거다!
	damage.sequential = true;
	local realDamage, reasons = ApplyDamageTest(owner, curDamage, 'Buff');
	local isDead = owner.HP <= realDamage;
	local remainHP = math.clamp(owner.HP - realDamage, 0, owner.MaxHP);

	DirectDamageByType(ds, owner, buff.HPChangeHitType, curDamage, remainHP, true, isDead, nil, 0);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	AddBuffDamageChat(ds, owner, buff, realDamage);
	return damage;
end
function Buff_Turn_Start_SelfDischarge(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end	
	
	-- 같은 버프를 걸어주는 지형 효과 위에 있으면 SelfDischarge가 발동하지 않는다. (어차피 다시 걸리니까...)
	local mission = GetMission(owner);
	local position = GetPosition(owner);
	local fieldEffects = GetFieldEffectByPosition(mission, position);
	for _, instance in ipairs(fieldEffects) do
		local affectors = SafeIndex(instance, 'Owner', 'BuffAffector');
		for i, affector in ipairs(affectors) do
			local applyBuffName = affector.ApplyBuff;
			if applyBuffName == buff.name then
				return;
			end
		end
	end
	
	local selfDischarge, selfDischargeDenominator = buff:GetSelfDischargeRate(owner);
	local selfDischargeRate = selfDischarge/selfDischargeDenominator;
	if selfDischargeRate >= math.random() then
		ds:Sleep(0.5);
		ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
		ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
		ds:Sleep(0.05);
		return Result_RemoveBuff(owner, buff.name);
	end
end
-- 공격 어빌리티를 사용하면 버프를 제거한다.
-- DischargeOnAttackType 으로 하위 속성 본다.
function Buff_AbilityUsed_DischargeOnAttack(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' or eventArg.Ability.ItemAbility then
		return;
	end
	if buff.DischargeOnAttackType ~= 'None' then
		if not IsGetAbilitySubType(eventArg.Ability, buff.DischargeOnAttackType) and eventArg.Ability.HitRateType ~= buff.DischargeOnAttackType then
			return;
		end
	end
	return Result_RemoveBuff(owner, buff.name, true);
end
-- 피해를 입으면 버프를 제거한다.
-- 자신의 피해도 역시 마찬가지.
function Buff_TakeDamage_DischargeOnHit(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner then
		return;
	end
	-- Miss나 힐은 반응안합니다.
	if eventArg.DamageBase <= 0 or eventArg.Damage == 0 then
		return;
	end
	if buff.DischargeOnHitDamageType ~= 'None' then
		-- 데미지 타입을 추정하고, 타입이 다르면 무시
		local damageType = eventArg.DamageInfo.damage_sub_type;   
		if eventArg.DamageInfo.damage_type == 'Buff' then
			damageType = eventArg.DamageInfo.damage_invoker.Group;
		end
		if damageType and damageType ~= buff.DischargeOnHitDamageType then
			return;
		end
	end
	
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	if buff.Group == 'Sleep' then
		table.insert(actions, Result_FireWorldEvent('RunIntoBattle', {Unit=owner, Trigger=eventArg.Giver, BuffType = buff.name}));
	end
	return unpack(actions);
end

function Buff_Turn_Start_ActionController(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if not buff.UseActionControlMessage and not GetCompany(owner) then
		return;
	end

	ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	ds:Sleep(1);
end
function Buff_Added_Message(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or buff.name ~= eventArg.BuffName then
		return;
	end

	if not eventArg.AbilityBuff then
		local visible = ds:EnableIf('TestObjectVisibleAndAlive', GetObjKey(owner));
		local buffAddID = ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
		ds:Connect(buffAddID, visible, -1);
		ds:SetCommandLayer(buffAddID, game.DirectingCommand.CM_SECONDARY);
		ds:SetContinueOnNormalEmpty(visible);
	end
end

function Buff_Immortal_TakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner then
		return;
	end
	local epsilon = 1E-12;
	if math.abs(owner.HP - 1) > epsilon then
		return;
	end
	local message = ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	ds:MakeIndependent(message);
end
function Buff_Turn_Start_Forward_Test(eventArg, buff, owner, giver, ds)
	if owner == eventArg.Unit and buff.Life == 1 then
		return Result_RemoveBuff(owner, buff.name);
	end
end
function Buff_Added_Brainwashing(eventArg, buff, owner, giver, ds)
	if buff ~= eventArg.Buff then	-- Brainwashing 관련 버프가 걸려있는 채로 거는건 금지!
		return;
	end
	if owner == giver then
		return;
	end
	local originalTeam = GetOriginalTeam(owner);
	SetInstantProperty(owner, 'OriginalTeam', originalTeam);
	SetInstantProperty(owner, 'Master', giver);
	local eternal = buff.Turn > 1000;
	if eternal then
		SetInstantProperty(owner, 'PreviousTeam' .. buff.name, originalTeam);
	end
	SetExpTaker(owner, giver);
	for i, action in ipairs(GetRemovePreBattleStateBuffActions(owner)) do
		ds:WorldAction(action, false);
	end
	return Result_ChangeTeam(owner, GetTeam(giver), not eternal);
end
function Buff_Removed_Brainwashing(eventArg, buff, owner, giver, ds)
	if buff ~= eventArg.Buff then	-- Brainwashing 관련 버프가 걸려있는데 해제되면 버그가 생길거임..
		return;
	end
	if owner == giver then
		return;
	end
	local rBuff = GetBuff(owner, buff.name);
	if rBuff then
		-- 이게 있다는건 버프가 지워졌지만 다시 길들이기가 걸려버렸다는 뜻..
		-- 그런데 어차피 이거 말고도 같은 Brainwashing버프가 걸려있어도 똑같이 문제 생길거라 크게 의미 없는 예외처리임
		-- 애초에 먼저 해제하고 다시 걸어야함
		return;
	end
	SetInstantProperty(owner, 'Master', nil);
	SetExpTaker(owner, nil);

	local newTeam = nil;
	local eternal = buff.Turn > 1000;
	if not eternal then
		newTeam = GetOriginalTeam(owner);
	else
		-- 花無十日紅
		newTeam = GetInstantProperty(owner, 'PreviousTeam' .. buff.name);
	end
	-- 야수 소환/기계 소환의 경우, 소환자의 팀을 따라간다
	local masterKey = GetInstantProperty(owner, 'SummonMaster');
	if masterKey ~= nil then
		local mission = GetMission(owner);
		local master = GetUnit(mission, masterKey, true);
		if master then
			newTeam = GetTeam(master);
		end
	end
	return Result_ChangeTeam(owner, newTeam, not eternal);
end
function Buff_UnitTeamChanged_Brainwashing(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= giver then
		return;
	end
	if owner == giver then
		return;
	end	
	local eternal = buff.Turn > 1000;
	return Result_ChangeTeam(owner, eventArg.Team, not eternal);		-- giver의 팀 변경을 따라간다
end
function Buff_UnitResurrect_Brainwashing(eventArg, buff, owner, giver, ds)
	local eternal = buff.Turn > 1000;
	if not eternal then
		return Result_RemoveBuff(owner, buff.name, true);
	end
end
function Buff_UnitMoved_DischargeOnMove(eventArg, buff, owner, giver, ds)
	return Result_RemoveBuff(owner, buff.name);
end
function Buff_PreAbilityUsing_DischargeOnAbility(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.ApplyTargetBuff.name == buff.name then
		return;
	end	
	if not buff.DischargeOnMove and IsMoveTypeAbility(eventArg.Ability) then
		return;
	end	
	return Result_RemoveBuff(owner, buff.name, true);
end
-- OverchargeEnded
function Buff_OverchargeEnded_DischargeOnOverchargeRelease(eventArg, buff, owner, giver, ds)
	return Result_RemoveBuff(owner, buff.name);
end
-- DischargeOnNoAttackableTarget
function Buff_UnitTurnStart_DischargeOnNoAttackableTarget(eventArg, buff, owner, giver, ds)
	local units = GetAllUnitInSight(owner, true);
	local targets = table.filter(units, function(o)
		return owner ~= o and IsEnemy(owner, o) and not o.PublicTarget and not o.Untargetable;
	end);
	if #targets > 0 then
		return;
	end
	local actions = {};
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	table.insert(actions, Result_TurnEnd(owner));
	return unpack(actions);
end
function Buff_AbilityHolder_Common_AddRef(giver, buff, owner)
	local refKey = 'AbilityHolder'..(GetWithoutError(buff, 'AbilityHolderKey') or buff.name);
	local refList = GetInstantProperty(giver, refKey) or {};
	local objKey = GetObjKey(owner);
	if not table.find(refList, objKey) then
		table.insert(refList, objKey);
		SetInstantProperty(giver, refKey, refList);
	end
	local actions = {};
	for _, targetAbility in ipairs(buff.HoldingAbility) do
		local ability = GetAbilityObject(giver, targetAbility);
		if ability then
			table.append(actions, {Buff_AbilityHolder_Common_UpdateCount(giver, ability, #refList)});
		end
	end
	return unpack(actions);
end
function Buff_AbilityHolder_Common_RemoveRef(giver, buff, owner)
	local refKey = 'AbilityHolder'..(GetWithoutError(buff, 'AbilityHolderKey') or buff.name);
	local refList = GetInstantProperty(giver, refKey) or {};
	local objKey = GetObjKey(owner);
	local fpos = table.find(refList, objKey);
	if fpos ~= nil then
		table.remove(refList, fpos);
		SetInstantProperty(giver, refKey, refList);
	end
	local actions = {};
	for _, targetAbility in ipairs(buff.HoldingAbility) do
		local ability = GetAbilityObject(giver, targetAbility);
		if ability then
			table.append(actions, {Buff_AbilityHolder_Common_UpdateCount(giver, ability, #refList)});
		end
	end
	return unpack(actions);
end
function Buff_AbilityHolder_Common_UpdateCount(giver, ability, refCount)
	local actions = {};
	local maxUseCount = ability.MaxUseCount;
	local newUseCount = math.clamp(maxUseCount - refCount, 0, maxUseCount);
	if ability.UseCount ~= newUseCount then
		table.insert(actions, Result_AbilityPropertyUpdated('UseCount', newUseCount, giver, ability.name, true));
	end
	return unpack(actions);
end
function Buff_AbilityHolder_MissionReinitialized(eventArg, buff, owner, giver, ds)
	return Buff_AbilityHolder_Common_AddRef(giver, buff, owner);
end
function Buff_AbilityHolder_Added(eventArg, buff, owner, giver, ds)
	local neutralizeBuff = GetWithoutError(buff, 'AbilityHolderNeutralizeBuff');
	if eventArg.Buff ~= buff and eventArg.Buff.name ~= neutralizeBuff then
		return;
	end
	if eventArg.Buff == buff then
		-- 이미 무효화 상태이면 레퍼런스 증감 없음
		if neutralizeBuff and HasBuff(owner, neutralizeBuff) then
			return;
		end
		return Buff_AbilityHolder_Common_AddRef(giver, buff, owner);
	else
		-- 무효화되었으니 레퍼런스 감소
		return Buff_AbilityHolder_Common_RemoveRef(giver, buff, owner);
	end	
end
function Buff_AbilityHolder_Removed(eventArg, buff, owner, giver, ds)
	local neutralizeBuff = GetWithoutError(buff, 'AbilityHolderNeutralizeBuff');
	if eventArg.Buff ~= buff and eventArg.Buff.name ~= neutralizeBuff then
		return;
	end
	if eventArg.Buff == buff then
		-- 이미 무효화 상태이면 레퍼런스 증감 없음
		if neutralizeBuff and HasBuff(owner, neutralizeBuff) then
			return;
		end
		return Buff_AbilityHolder_Common_RemoveRef(giver, buff, owner);
	else
		-- 무효화가 해제되었으니 레퍼런스 증가
		return Buff_AbilityHolder_Common_AddRef(giver, buff, owner);
	end
end
function Buff_AbilityHolder_UnitDead(eventArg, buff, owner, giver, ds)
	return Buff_AbilityHolder_Common_RemoveRef(giver, buff, owner);
end
function Buff_AbilityHolder_UnitDead_Virtual(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or not eventArg.Virtual then
		return;
	end
	return Buff_AbilityHolder_Common_RemoveRef(giver, buff, owner);
end
function Buff_AbilityHolder_UnitResurrect(eventArg, buff, owner, giver, ds)
	return Buff_AbilityHolder_Common_AddRef(giver, buff, owner);
end
function Buff_FieldEffectSlave_UnitTurnEnd(masterFieldAffector)
	return function(eventArg, buff, owner, giver, ds)
		local myPos = GetPosition(owner);
		local fieldEffects = GetFieldEffectByPosition(GetMission(owner), myPos);
		for _, instance in ipairs(fieldEffects) do
			for __, buffAffector in ipairs(instance.Owner.BuffAffector) do
				if buffAffector.name == masterFieldAffector then
					return;
				end
			end
		end
		
		-- 여기 왔으면 통과 못한거임
		return Result_RemoveBuff(owner, buff.name, true);
	end;
end
function Buff_Common_InvalidateAuraTarget(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	return Result_FireWorldEvent('InvalidateAuraTarget_Self', {Unit = owner}, owner), Result_FireWorldEvent('InvalidateAuraTarget', {Unit = owner});
end
----- 개별 이벤트 핸들러 ------
---------------------------
function Buff_Turn_Start_SelfRecovery(eventArg, buff, owner)
	if eventArg.Unit ~= owner then
		return;
	end
	local damage =  -1 * math.floor( owner.MaxHP * 0.3);
	local result = {};
	result.type = "Damage";
	result.damage = damage;
	ShowObjectMessage(owner, 'Heal :        '..tostring(damage).."!");
	return result;
end
function Buff_Overwatching_TestMoveStep(eventArg, buff, owner, giver, ds)
	local mission = GetMission(owner);
	local alreadyObj = GetObjectByPosition(mission, eventArg.Position);
	if alreadyObj ~= nil and alreadyObj ~= eventArg.Unit then
		-- 이 위치에 이미 누군가 있어!
		return;
	end

	local removeBuff = Result_RemoveBuff(owner, 'Overwatching');
	
	local overwatch = FindAbility(owner, owner.OverwatchAbility_Force);
	if overwatch == nil then
		return removeBuff;
	end
	local rangeClsList = GetClassList('Range');
	local range = CalculateRange(owner, overwatch.TargetRange, GetPosition(owner));
	local p = eventArg.Position;
	if BuffHelper.IsPositionInRange(p, range) then
		local eventCmd = ds:SubscribeFSMEvent(GetObjKey(eventArg.Unit), 'StepForward', 'CheckUnitArrivePosition', {CheckPos=p}, true, true);
		if eventArg.MoveID and ds:GetRefID(eventArg.MoveID) ~= eventArg.MoveID then
			ds:Connect(eventCmd, eventArg.MoveID, 0);		-- 루프를 만들어서 교체를 시키려고
			ds:Connect(eventArg.MoveID, eventCmd, 0);
		else
			ds:SetConditional(eventCmd);
		end
		
		local hitCount = eventArg.OverwatchHitCount or 0;
		ds:WorldAction(removeBuff);
		local targetPos = GetPosition(eventArg.Unit);
		local resultModifier = {ReactionAbility=true, Overwatch=true, Moving=true, Dash=eventArg.IsDash, BattleEvents={{Object = owner, EventType = 'OverwatchingShot', Args = nil}}};
		local mastery_ImWatching = GetMasteryMastered(GetMastery(owner), 'ImWatching');
		if mastery_ImWatching and HasBuff(eventArg.Unit, mastery_ImWatching.Buff.name) then
			resultModifier.Inevitable = true;
			resultModifier.CriticalHit = true;
			table.insert(resultModifier.BattleEvents, { Object = owner, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery_ImWatching.name}});
		end
		
		local overwatchAction = Result_UseAbilityTarget(owner, overwatch.name, eventArg.Unit, resultModifier, true, {NoCamera=true, Preemptive=true, PreemptiveOrder=hitCount});
		overwatchAction.nonsequential = true;
		overwatchAction.free_action = true;
		overwatchAction._ref = eventCmd;
		overwatchAction._ref_offset = -1;
		eventArg.OverwatchHitCount = hitCount + 1;
		return overwatchAction;
	end
end
function Buff_Overwatching_UnitMovedSingleStep(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or eventArg.Unit.HP <= 0
		or eventArg.StepCount <= 1 -- 제자리 이동은 무시한다
		or eventArg.Unit.PreBattleState 
		or eventArg.Unit.Cloaking
		or SafeIndex(eventArg, 'Invoker', 'Unit') == owner
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or GetBuff(eventArg.Unit, 'FeatherWalk') then
		return;
	end
	return Buff_Overwatching_TestMoveStep(eventArg, buff, owner, giver, ds);
end
function Buff_Overwatching_UnitPositionChanged(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or eventArg.Unit.HP <= 0
		or eventArg.Unit.PreBattleState
		or eventArg.Unit.Cloaking
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or GetBuff(eventArg.Unit, 'FeatherWalk') 
		or eventArg.Blink then
		return;
	end
	return Buff_Overwatching_TestMoveStep(eventArg, buff, owner, giver, ds);
end
function Buff_Flow_TestMoveStep(eventArg, buff, owner, giver, ds, reposition, abilityName)
	local flowAlreadyHitSet = GetInstantProperty(owner, 'FlowAlreadyHitSet') or {};
	if flowAlreadyHitSet[GetObjKey(eventArg.Unit)] then
		return;
	end
	local mission = GetMission(owner);
	local alreadyObj = GetObjectByPosition(mission, eventArg.Position);
	if alreadyObj ~= nil and alreadyObj ~= eventArg.Unit then
		-- 이 위치에 이미 누군가 있어!
		return;
	end

	local overwatch = FindAbility(owner, abilityName);
	if overwatch == nil then
		return;
	end
	local flowWatchingArea = GetInstantProperty(owner, 'FlowWatchingArea');
	if not flowWatchingArea then
		LogAndPrint('[ERROR] Watching Area가 존재하지 않음');
		return;
	end
	local p = eventArg.Position;
	if BuffHelper.IsPositionInRange(p, flowWatchingArea) then
		local eventCmd = ds:SubscribeFSMEvent(GetObjKey(eventArg.Unit), 'StepForward', 'CheckUnitArrivePosition', {CheckPos=p}, true, true);
		
		flowAlreadyHitSet[GetObjKey(eventArg.Unit)] = true;
		SetInstantProperty(owner, 'FlowAlreadyHitSet', flowAlreadyHitSet);
		if eventArg.MoveID and ds:GetRefID(eventArg.MoveID) ~= eventArg.MoveID then
			ds:Connect(eventCmd, eventArg.MoveID, 0);		-- 루프를 만들어서 교체를 시키려고
			ds:Connect(eventArg.MoveID, eventCmd, 0);
		else
			ds:SetConditional(eventCmd);
		end
		
		local hitCount = eventArg.OverwatchHitCount or 0;
		local targetPos = GetPosition(eventArg.Unit);
		
		local battleEvents = {{Object = owner, EventType = 'BuffInvoked', Args = {Buff = buff.name}}};
		local overwatchAction = Result_UseAbilityTarget(owner, abilityName, eventArg.Unit, {ReactionAbility=true, Flow=true, Moving=true, Dash=eventArg.IsDash, BattleEvents=battleEvents}, true, {NoCamera=true, Preemptive=true, PreemptiveOrder=hitCount});
		overwatchAction.nonsequential = true;
		overwatchAction.free_action = true;
		overwatchAction._ref = eventCmd;
		overwatchAction._ref_offset = -1;
		eventArg.OverwatchHitCount = hitCount + 1;
		
		local applyAct = 30;
		local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
		if action then
			table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
		end
		table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
		return overwatchAction, action;
	end	
end
function Buff_Flow_UnitMovedSingleStep(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or eventArg.Unit.HP <= 0
		or eventArg.StepCount <= 1 -- 제자리 이동은 무시한다
		or eventArg.Unit.PreBattleState 
		or eventArg.Unit.Cloaking
		or SafeIndex(eventArg, 'Invoker', 'Unit') == owner
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or GetBuff(eventArg.Unit, 'FeatherWalk') then
		return;
	end
	return Buff_Flow_TestMoveStep(eventArg, buff, owner, giver, ds, true, owner.OverwatchAbility_Force);
end
function Buff_Flow_UnitPositionChanged(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or eventArg.Unit.HP <= 0
		or eventArg.Unit.PreBattleState
		or eventArg.Unit.Cloaking
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or GetBuff(eventArg.Unit, 'FeatherWalk') 
		or eventArg.Blink then
		return;
	end
	return Buff_Flow_TestMoveStep(eventArg, buff, owner, giver, ds, false, owner.OverwatchAbility_Force);
end
function Buff_CrammyVolcano_UnitMovedSingleStep(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or eventArg.Unit.HP <= 0
		or eventArg.StepCount <= 1 -- 제자리 이동은 무시한다
		or eventArg.Unit.PreBattleState 
		or eventArg.Unit.Cloaking
		or SafeIndex(eventArg, 'Invoker', 'Unit') == owner
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or GetBuff(eventArg.Unit, 'FeatherWalk') then
		return;
	end
	return Buff_Flow_TestMoveStep(eventArg, buff, owner, giver, ds, true, 'Fireball_Vocano');
end
function Buff_CrammyVolcano_UnitPositionChanged(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or eventArg.Unit.HP <= 0
		or eventArg.Unit.PreBattleState
		or eventArg.Unit.Cloaking
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or GetBuff(eventArg.Unit, 'FeatherWalk') 
		or eventArg.Blink then
		return;
	end
	return Buff_Flow_TestMoveStep(eventArg, buff, owner, giver, ds, false, 'Fireball_Vocano');
end

function Buff_TakeDamage_CautionExplosionRisk(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner then
		return;
	end
	
	print("### Buff_TakeDamage_CautionExplosionRisk ###", owner.name);
	
	local removeBuff = Result_RemoveBuff(owner, 'CautionExplosionRisk');
	local addBuff = Result_AddBuff(owner, owner, 'OneTurnLeftUntilExplosion', 1);
	
	local removeBuffID = ds:WorldAction(removeBuff);
	local useExplosion = ds:WorldAction(Result_UseAbility(owner, 'Explosion', GetPosition(owner)));
	local changeShape = ds:WorldAction({type="ChangeShape", target=owner, shape=owner.BrokenShape});
	ds:SetContinueOnEmpty(removeBuffID);
	ds:Connect(useExplosion, removeBuffID, -1);
	ds:Connect(changeShape, useExplosion, 0.2);
end

function Buff_TurnStart_OneTurnLeftUntilExplosion(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local removeBuff = Result_RemoveBuff('OneTurnLeftUntilExplosion');
	local explosion = FindAbility(owner, 'Explosion');
	if explosion == nil then
		return removeBuff;
	end
	
	return removeBuff;
end
----------------- 순찰  ----------------------
local PatrolFindModeConfiguration = {
	DetectEnemy = {
		OwnerDetectWord = 'DetectEnemy',
		OwnerDetectIcon = 'Icons/Scan',
		OwnerDetectVoice = 'Detect',
		FindObjDetectedWord = 'Detected',
		FindObjDetectedIcon = 'Icons/Alert',
		FindObjDetectedVoice = 'Detected'
	},
	Surprised = {
	},
	DetectEnemyEachother = {
		NoAlertLine = true
	},
	SupportCall = {
		FindObjDetectedWord = 'SupportCall',
		FindObjDetectedIcon = 'Icons/Scan',
		FindObjDetectedVoice = 'None'
	},
	ExtraSupportCall = {	--- 사실 쓰이지는 않음.. 왜냐면 ExtraSupportCall은 SupportCall의 WakeProcess랑 동시에 움직일거라..
		FindObjDetectedWord = 'SupportCall',
		FindObjDetectedIcon = 'Icons/Scan',
		FindObjDetectedVoice = 'None'
	},
	DetectAlly = {
		OwnerDetectWord = 'DetectAlly',
		OwnerDetectIcon = 'Icons/Scan',
	},
};

function HasMastery(obj, masteryName)
	local masteryTable = GetMastery(obj);
	local mastery = GetMasteryMastered(masteryTable, masteryName);
	
	return (mastery ~= nil);
end

function Buff_Patrol_FindEnemy(owner, findObj, findPos, ds, ownerMoved, moveID, noDetectDirecting, buffType, findBySearch, moveDestination)
	local findObjectKey = GetObjKey(findObj);
	local ownerKey = GetObjKey(owner);
	local targetKey = GetObjKey(findObj);
	SetInstantProperty(owner, 'Invoker', findObj);
	local connectID = nil;
	local detectID = nil;
	buffType = buffType or 'Stand';
	findBySearch = findBySearch or false;
	
	local mode;
	if GetRelation(owner, findObj) == 'Enemy' then
		if GetInstantProperty(findObj, 'MovingForAbility') then
			mode = 'Surprised';
		elseif GetInstantProperty(findObj, 'Invoker') == owner then
			mode = 'DetectEnemyEachother';
		else
			mode = 'DetectEnemy';
		end
	elseif IsTeamOrAlly(owner, findObj) and HasBuff(findObj, 'Silence') then
		mode = 'DetectAlly';
		findPos = GetPosition(findObj);
	elseif HasBuff(findObj, 'SupportMoving') then
		mode = 'ExtraSupportCall';
	else
		mode = 'SupportCall';
	end
	
	local alertParticleName;
	if buffType == 'Stand' then
		alertParticleName = 'Particles/Dandylion/Selection_AlertStand';
	elseif buffType == 'Detecting' then
		alertParticleName = 'Particles/Dandylion/Selection_AlertDetecting';
	else
		alertParticleName = 'Particles/Dandylion/Selection_Alert';
	end
	
	local modeConfigBase = PatrolFindModeConfiguration[mode];
	if modeConfigBase == nil then
		modeConfigBase = PatrolFindModeConfiguration.DetectEnemy;
	end

	local masteryTable = GetMastery(findObj);
	-- 살금 살금/슬금 슬금
	local mastery_StealthyFootsteps = GetMasteryMasteredLikeStealthyFootsteps(masteryTable);
	-- 속임수 거래
	local mastery_TricksTrade = GetMasteryMastered(masteryTable, 'TricksTrade');

	local modeConfig = table.deepcopy(modeConfigBase);
	if mode == 'DetectEnemy' then
		local surprizeMoveCounter = GetInstantProperty(findObj, 'SurprizeMoveCounter') or 0;
		if not ownerMoved and surprizeMoveCounter > 0 then
			modeConfig.NoMoveDetect = true;
		end
		-- 살금 살금/슬금 슬금
		if mastery_StealthyFootsteps and mastery_StealthyFootsteps.CountChecker > 0 and findPos and not ownerMoved then
			modeConfig.NoMoveDetect = true;
			modeConfig.StealthyFootsteps = true;
		end
		-- 속임수 거래
		if mastery_TricksTrade and not findPos and not ownerMoved then
			modeConfig.NoMoveDetect = true;
			modeConfig.TricksTrade = true;
		end
		if buffType == 'Detecting' then
			modeConfig.OwnerDetectWord = 'DetectEnemyAlert'
			local buff = GetBuff(owner, buffType);
			buff.DuplicateApplyChecker = 1;
		end
	elseif mode == 'Surprised' then
		if buffType == 'Detecting' then
			local buff = GetBuff(owner, buffType);
			buff.DuplicateApplyChecker = 1;
		end
	end
	
	local needReleaseFindObject = findPos ~= nil;
	if findPos then
		local moveObjectKey = (ownerMoved and ownerKey or findObjectKey);
		local eventCmd = nil;
		if not findBySearch then
			eventCmd = ds:SubscribeFSMEvent(moveObjectKey, 'StepForward', 'CheckUnitArrivePosition', {CheckPos=findPos}, true, true);
			if moveID then
				ds:Connect(eventCmd, moveID, 0);
				ds:Connect(moveID, eventCmd, 0);
			else
				ds:SetConditional(eventCmd);
			end
		else
			eventCmd = ds:Sleep(0);
		end
		local visible = ds:EnableIf('TestObjectVisibleAndAliveMulti', {ObjectList = {ownerKey, findObjectKey}, Mode = 'Or'});
		ds:Connect(visible, eventCmd, -1);
		eventCmd = visible;
		local ownerPos = (ownerMoved and findPos or GetPosition(owner));
		local camMoveTime = 1;
		ds:Connect(ds:StopUpdate(ownerKey), eventCmd, -1);
		ds:Connect(ds:StopUpdate(findObjectKey), eventCmd, -1);
		
		local ownerCamMove = ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false, camMoveTime);
		ds:Connect(ownerCamMove, eventCmd, -1);
		if modeConfig.OwnerDetectWord then
			local detectMessage = ds:UpdateBattleEvent(ownerKey, 'GetWordAliveOnly', { Color = 'Red', Word = modeConfig.OwnerDetectWord });
			ds:Connect(detectMessage, ownerCamMove, camMoveTime - 0.5);
		end
		
		if ownerMoved then
			connectID = ownerCamMove;
		else
			-- 오너가 움직인게 아니라면 StopUpdate를 미리 풀고 대상을 바라봄
			-- 돌아보기 시작한후 0.1 초 후에 대상의 업데이트를 풀음.
			local rotateLook = ds:LookAt(ownerKey, findObjectKey);
			ds:Connect(rotateLook, ownerCamMove, -1);
			ds:Connect(ds:ContinueUpdate(ownerKey), rotateLook, 0.1);
			connectID = rotateLook;
		end
		if buffType == 'Detecting' then
			ds:Connect(ds:PlayParticle(ownerKey, '_TOP_', 'Particles/Dandylion/DetectingAlertScan', 1), connectID, -1);
		end
		ds:TemporarySightWithThisAction(ownerPos, 1, eventCmd, -1, connectID, -1);
				
		local stopObjKey = ownerMoved and findObjectKey or ownerKey;
		local fObjKey = ownerMoved and ownerKey or findObjectKey;

		if not modeConfig.NoAlertLine then
			ds:Connect(ds:ShowAlertLine(fObjKey, stopObjKey, alertParticleName), ownerCamMove, -1);
		end
		local sleepID = ds:Sleep(0.05);
		ds:Connect(sleepID, connectID, -1);
		
		local camMoveTime2 = 1;
		local findObjCamMove = ds:ChangeCameraTarget(findObjectKey, '_SYSTEM_', false, false, camMoveTime2);
		ds:Connect(findObjCamMove, sleepID, -1);
		local findObjCamSleep = ds:Sleep(0.5);
		ds:Connect(findObjCamSleep, findObjCamMove, -1);
		connectID = findObjCamSleep;
		
		if modeConfig.FindObjDetectedWord then
			local detectedMessage = ds:UpdateBattleEvent(findObjectKey, 'GetWordAliveOnly', { Color = 'Red', Word = modeConfig.FindObjDetectedWord });
			ds:Connect(detectedMessage, findObjCamMove, camMoveTime2 - 0.5);
		end
		
		local alertScreenEffect = ds:AlertScreenEffect(findObjectKey);
		ds:Connect(alertScreenEffect, findObjCamMove, camMoveTime2 - 0.5);
		
		if modeConfig.FindObjDetectedVoice and not GetBuffStatus(findObj, 'Unconscious', 'Or')  then
			ds:PlayVoiceAndText(findObj, modeConfig.FindObjDetectedVoice, false, 0, findObjCamMove, 0);
		end
		
		if ownerMoved then
			local continueID = ds:ContinueUpdate(ownerKey);
			ds:Connect(continueID, connectID, -1);
		
			-- 적 발견 전까지는 걷다가, 적 발견 후에는 원래 이동 목표 지점까지 걷지 않고 뛰어가게 만들기 위한 연출용 이동 처리
			-- Buff_Patrol_Wakeup_Process 내의 Patrol 버프 해제 로직이 클라에 적용이 된 후에 이동을 시작하도록 약간의 딜레이를 줌
			local sleepID = ds:Sleep(0.05);
			ds:Connect(sleepID, continueID, -1);
		
			local movePos = GetPosition(owner);
			ds:Connect(ds:Move(ownerKey, movePos, false, false, '', nil, nil, nil, nil, nil, nil, nil, true), sleepID, -1);	-- 멈추기
			
			detectID = continueID;
		end
	elseif not (ownerMoved or mode == 'ExtraSupportCall' or mode == 'DetectAlly') then
	-- 그 외 적에게 들킴.
		local camMoveTime = 1;
		local findObjCamMove = ds:ChangeCameraTargetingMode(findObjectKey, ownerKey, '_SYSTEM_', false, false, camMoveTime);
		
		if modeConfig.FindObjDetectedWord then
			local detectedMessage = ds:UpdateBattleEvent(findObjectKey, 'GetWord', { Color = 'Red', Word = modeConfig.FindObjDetectedWord });
			ds:Connect(detectedMessage, findObjCamMove, camMoveTime - 0.5);
		end
		
		local alertScreenEffect = ds:AlertScreenEffect(findObjectKey);
		local sleepID4 = ds:Sleep(0.05);
		ds:Connect(alertScreenEffect, findObjCamMove, camMoveTime - 0.5);
		ds:Connect(sleepID4, findObjCamMove, -1);
		connectID = sleepID4;
		if buffType == 'Detecting' then
			if modeConfig.OwnerDetectWord then
				local detectMessage = ds:UpdateBattleEvent(ownerKey, 'GetWordAliveOnly', { Color = 'Red', Word = modeConfig.OwnerDetectWord });
				ds:Connect(detectMessage, findObjCamMove, camMoveTime - 0.5);
			end
			ds:Connect(ds:PlayParticle(ownerKey, '_TOP_', 'Particles/Dandylion/DetectingAlertScan', 1), connectID, -1);
		end
	end
	
	if noDetectDirecting == nil then
		noDetectDirecting = false;
	end
	-- 발견 동작
	-- 소유자가 이동한 경우는 끝나고 연출.
	-- 그렇지 않은 경우는 이동과 동시에 연출
	local visible = ds:EnableIf('TestObjectVisibleAndAliveMulti', {ObjectList = {ownerKey, findObjectKey}, Mode = 'Or'});
	if connectID ~= nil then
		ds:Connect(visible, connectID, -1);
	end
	connectID = visible;
	if owner.HP > 0 and mode == 'DetectEnemy' or mode == 'DetectAlly' then
		-- 이처리가 진행중일때는 살아있어도 이후의 처리에 의해서 오너가 죽을 수 있음
		-- 따라서 클라단에서의 연출여부 체크를 위한 로직이 필요함
		local camAni_start = nil;
		local look = ds:LookAt(ownerKey, findObjectKey);
		
		if not noDetectDirecting then
			camAni_start = ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false);
			ds:Connect(camAni_start, connectID, -1);
			ds:Connect(look, camAni_start, 0);
			if modeConfig.OwnerDetectVoice and not GetBuffStatus(owner, 'Unconscious', 'Or') then
				local voiceAndTextID = ds:PlayVoiceAndText(owner, modeConfig.OwnerDetectVoice, true, 0, camAni_start, 0);
			end
		end
		if needReleaseFindObject then
			ds:Connect(ds:ContinueUpdate(findObjectKey), connectID, -1);
		end
	elseif needReleaseFindObject then
		ds:Connect(ds:ContinueUpdate(findObjectKey), connectID, -1);
	end
	local actions = {Buff_Patrol_Wakeup_Process(owner, findObj, ds, modeConfig.NoMoveDetect, moveID, mode, detectID, buffType, ownerMoved, moveDestination, modeConfig)};
	
	if GetRelation(owner, findObj) == 'Enemy' then
		table.insert(actions, Result_FireWorldEvent('PatrolDetected', {Unit=findObj, Target=owner, Type=buffType}));
	end

	-- 살금 살금/슬금 슬금
	if mastery_StealthyFootsteps and modeConfig.StealthyFootsteps then
		table.append(actions, { Mastery_StealthyFootsteps_Invoked(nil, mastery_StealthyFootsteps, findObj, ds, findPos) });
	end

	return unpack(actions);
end
function GetRemovePreBattleStateBuffActions(obj)
	local actions = {};
	for i, buff in ipairs(GetBuffList(obj)) do
		if buff.PreBattleState then
			table.insert(actions, Result_RemoveBuff(obj, buff.name));
		end
	end
	return actions;
end
function Buff_Patrol_Wakeup_Process(owner, findObj, ds, noMoveDetect, connectMoveID, mode, detectID, buffType, ownerMoved, moveDestination, modeConfig)
	local sleepID = ds:Sleep(0.05);
	local buffList = GetClassList('Buff');
	local awakeRange = -1 * buffList[buffType].SightRange;
	if GetBuff(owner, 'Silence') then
		awakeRange = 0;
	end
	local fullRange = owner.SightRange + awakeRange;
	local nearUnits = GetAllUnitInSight(owner, true, fullRange);

	local mission = GetMission(owner);
	local groupUnits = GetGroupObjects(mission, owner);
	if #groupUnits > 0 then
		local ownerPos = GetPosition(owner);
		for _, obj in ipairs(groupUnits) do
			local dist = GetDistance3D(ownerPos, GetPosition(obj));
			if dist <= fullRange and not table.find(nearUnits, obj) then
				table.insert(nearUnits, obj);
			end
		end;
	end

	local masteryTable = GetMastery(findObj);
	-- 추적하는 눈
	local mastery_ChaserEyes = GetMasteryMastered(masteryTable, 'ChaserEyes');
	-- 퇴로
	local mastery_EscapeRoute = GetMasteryMastered(masteryTable, 'EscapeRoute');
	
	local nearTeam = table.filter(nearUnits, function(obj)
		local rel = GetRelation(owner, obj);
		return obj.PreBattleState and (rel == 'Team' or rel == 'Ally') and obj.HP > 0 and not HasBuff(obj, 'FakeInformation'); 	-- 시야 내에 있으면서 순찰 중이면서 같은 팀만
	end);
	-- 중복 위치 점유처럼 GetAllUnitInSight에 자신이 포함되지 않는 상황이 발생할 수 있으므로, 깨우는 대상에 자신이 꼭 포함되게 처리함
	if owner.PreBattleState and not table.find(nearTeam, owner) then
		table.insert(nearTeam, owner);
	end
		
	local patrolEnemyPos = GetInstantProperty(owner, 'PatrolEnemyPosition');
	
	local affectedActors = nearTeam;
	-- Detecting을 가진 객체를 최대한 뒤로 미룬다
	table.sort(affectedActors, function (a, b)
		local ordera = GetInstantProperty(a, 'RetreatOrder') or 999;
		local orderb = GetInstantProperty(b, 'RetreatOrder') or 999;
		if ordera ~= orderb then
			return ordera < orderb;
		end
		local haveDetectingA = GetBuff(a, 'Detecting') ~= nil;
		local haveDetectingB = GetBuff(b, 'Detecting') ~= nil;
		if haveDetectingA == haveDetectingB then
			return tostring(a) < tostring(b);
		elseif haveDetectingA then
			return false;
		else
			return true;
		end
	end);
	
	local actions = {};
	for i, actor in ipairs(affectedActors) do
		(function()
			local connectID = sleepID;
			local offset = -1;
			if detectID then
				connectID = detectID;
				offset = -1;
			end
			-- 순찰 해제. WorldAction으로 처리해야 순서가 맞음. 이동하다가 맞으면 또 적용할수도 있으니까
			SetInstantProperty(actor, 'NoTurnEndMove', true);
			for i, action in ipairs(GetRemovePreBattleStateBuffActions(actor)) do
				local removeId = ds:WorldAction(action, true);
				ds:Connect(removeId, connectID, offset);
			end
			SetInstantProperty(actor, 'NoTurnEndMove', nil);
			-- 이동이 곤란한 유닛은 순찰 버프만 지우고 종료
			if IsDead(actor) or not actor.Movable then
				return;
			end
			if GetBuff(actor, 'Berserker') ~= nil
				or GetBuff(actor, 'Confusion') ~= nil then
				return;
			end
			if mode == 'SupportCall' or mode == 'ExtraSupportCall' then
				local supportID = ds:WorldAction(Result_AddBuff(actor, actor, 'SupportMoving', 1));
				ds:Connect(supportID, connectID, offset);
			end
			table.insert(actions, Result_StopMove(actor));
		end)();
	end
	
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		local sleepID = ds:Sleep(0.05);
		-- 버프를 먼저 모두 해제해 두고 이동을 시키자 (그래야 한명한명 이동하다가 연쇄로 풀리지 않을듯)
		local actions = {};
		local aiSession = GetAISession(owner, GetTeam(owner));
		local alreadyOccupiedPositions = aiSession:GetReservedPatrolRetreatPositions();
		local startIndex = #alreadyOccupiedPositions + 1;
		local findObjPrevPos = GetPosition(findObj);
		if not ownerMoved and moveDestination then
			SetPosition(findObj, moveDestination);
		end
		
		for i, actor in ipairs(affectedActors) do
			(function()	-- break
				if IsDead(actor) or not actor.Movable then
					return;
				end
				if GetBuff(actor, 'Berserker') ~= nil
					or GetBuff(actor, 'Confusion') ~= nil then
					return;
				end
				
				local connectID = sleepID;
				local offset = -1;
				if mode == 'ExtraSupportCall' then
					connectID = connectMoveID;
					offset = 0;
				end
				
				-- 추적하는 눈
				if mastery_ChaserEyes and (mode == 'DetectEnemy' or mode == 'Surprised') and findObj then
					local chat = ds:UpdateBalloonChat(GetObjKey(actor), '!', 'Shout_Enemy');
					if connectID then
						ds:Connect(chat, connectID, offset);
					end
				end
				-- 퇴로
				if mastery_EscapeRoute and SafeIndex(modeConfig, 'TricksTrade') then
					InsertBuffActions(actions, findObj, actor, mastery_EscapeRoute.SubBuff.name, 1, true);
				end
				
				local actorPos = GetPosition(actor);
				local from = table.deepcopy(actorPos);
				local r = actor.Race.RunIntoBattleMoveRange;
				from.x = from.x - r;
				from.y = from.y - r;
				local to = table.deepcopy(actorPos);
				to.x = to.x + r;
				to.y = to.y + r;
				
				-- 순찰 해제 후에 이동위치를 찾아야 제대로임
				local aiArgs = {};
				aiArgs.RallyPoint = patrolEnemyPos;
				aiArgs.ActivityArea = {{From = {from}, To = {to}}};
				aiArgs.ActorPos = actorPos;
				local pos = nil;
				local maxDist = nil;
				-- 튜토리얼시 정확한 위치로 이동을 해야하는데 --
				local retreatPosition = GetInstantProperty(actor, 'RetreatPosition');
				if retreatPosition and retreatPosition.x ~= -1 and retreatPosition.y ~= -1 and retreatPosition.z ~= -1 then
					pos = retreatPosition;
				end
				-- 그림자 걷기는 제자리에 있어야 한다. 그렇다고 Move를 안 하면 지원요청이 안 동작하므로 현재 자리로...
				if noMoveDetect or GetBuff(actor, 'Blind') ~= nil then
					pos = GetPosition(actor);
				end
				if pos == nil then
					local moveAI = PatrolAwakeMoveAI;
					local monCls = SafeIndex(GetClassList('Monster'), GetInstantProperty(actor, 'MonsterType'));
					if monCls.PatrolAwakeMoveAI then
						moveAI = monCls.PatrolAwakeMoveAI;
					end
					local moveDist = actor.MoveDist * (1 + actor.SecondaryMoveRatio);
					moveDist = math.min(moveDist, r * 2) + 0.4;
					pos = FindAIMovePosition(actor, {FindMoveAbility(actor)}, function (self, adb, args)
						if adb.MoveDistance > moveDist then
							return -100;	-- 거리제한
						end
						return moveAI(self, adb, args);
					end, {NoneBlock = true, RejectPositions = alreadyOccupiedPositions}, aiArgs);
					if pos == nil then
						return;
					end
					maxDist = moveDist;
				end
				table.insert(alreadyOccupiedPositions, pos);
				aiSession:ReservePatrolRetreatPosition(pos);
				

				if mode == 'Surprised' then
					SetInstantProperty(actor, 'AwakenRightBefore', true);
					ds:ReserveMove(GetObjKey(actor), pos, nil, false, maxDist, maxDist, true);
					SubscribeWorldEvent(actor, 'UnitMoved_Self', function(eventArg, ds, subscriptionID)
						SetInstantProperty(actor, 'AwakenRightBefore', nil);
						UnsubscribeWorldEvent(actor, subscriptionID);
					end);
				else
					local forceAni = 'Rush';
					local moveAniSpeed = actor.Shape.MoveCameraAniSpeed;
					local moveID = ds:Move(GetObjKey(actor), pos, false, true, forceAni, maxDist, maxDist, nil, moveAniSpeed, nil, nil, nil, true);
					local moveAction = Result_Move(pos, actor, maxDist, maxDist);
					moveAction._ref = moveID;
					moveAction._ref_offset = 0;
					moveAction.directing_id = moveID;
					moveAction.forward = true;
					table.insert(actions, moveAction);
					if connectID then
						ds:Connect(moveID, connectID, offset);	-- 동시에 이동하자
					end
				end
			end)();
			table.insert(actions, Result_FireWorldEvent('RunIntoBattle', {Unit=actor, Trigger=findObj, BuffType = buffType}));
		end
		if not ownerMoved and moveDestination then
			SetPosition(findObj, findObjPrevPos);
		end
		table.insert(actions, Result_DirectingScript(function(mid, ds, args)
			for i = startIndex, #alreadyOccupiedPositions do
				aiSession:FreePatrolRetreatPosition(alreadyOccupiedPositions[i]);
			end
		end));
		return unpack(actions);
	end, nil, true, true));
	return unpack(actions);
end

-- 순찰 버프의 경우 어빌리티의 사용대상에 포함되었을때와 어빌리티의 사용 반경이 유닛의 시야 내에 들었을때를 나누어서 핸들링한다.
-- 이유는 어빌리티의 영향권에 속한 오브젝트가 우선적으로
function Buff_StartingBuff_AbilityUsed_Affected(eventArg, buff, owner, giver, ds, buffType)
	if owner == eventArg.Unit
		or owner.HP <= 0
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy' --유저가 아닌 적에 의해서도 깨어나는가?
		or IsMoveTypeAbility(eventArg.Ability)
		or eventArg.Ability.Mute
		or eventArg.Ability.SilentMove then
		return;
	end

	for i, targetInfos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, targetInfo in ipairs(targetInfos) do
			if targetInfo.Target == owner then
				SetInstantProperty(owner, 'PatrolEnemyPosition', GetPosition(eventArg.Unit));
				return Buff_Patrol_FindEnemy(owner, eventArg.Unit, nil, ds, not owner.TurnState.TurnEnded, nil, nil, buffType);
			end
		end
	end
end
function Buff_Patrol_AbilityUsed_Affected(eventArg, buff, owner, giver, ds)
	return Buff_StartingBuff_AbilityUsed_Affected(eventArg, buff, owner, giver, ds, 'Patrol');
end
function Buff_Stand_AbilityUsed_Affected(eventArg, buff, owner, giver, ds)
	return Buff_StartingBuff_AbilityUsed_Affected(eventArg, buff, owner, giver, ds, 'Stand');
end
function Buff_Detecting_AbilityUsed_Affected(eventArg, buff, owner, giver, ds)
	return Buff_StartingBuff_AbilityUsed_Affected(eventArg, buff, owner, giver, ds, 'Detecting');
end

function Buff_StartingBuff_AbilityUsed_InSight(eventArg, buff, owner, giver, ds, buffType)
	if owner == eventArg.Unit
		or owner.HP <= 0
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy' --유저가 아닌 적에 의해서도 깨어나는가?
		or IsMoveTypeAbility(eventArg.Ability)
		or eventArg.Ability.Mute
		or eventArg.Ability.SilentMove then
		return;
	end
	-- 은신 상태의 어빌리티 사용은 사용대상에 포함되었을 때만 적용 (Buff_StartingBuff_AbilityUsed_Affected)
	if eventArg.Unit.Cloaking then
		return;
	end
	-- 단일 대상의 회복, 지원, 행동 어빌리티를 자신에게 사용했을 경우에만 허용
	local unit = eventArg.Unit;
	local ability = eventArg.Ability;
	local usingPos = eventArg.PositionList[1];
	if IsInSight(owner, usingPos, true) and ability.TargetType == 'Single' and (ability.Type == 'Heal' or ability.Type == 'Assist' or ability.Type == 'StateChange') and IsSamePosition(usingPos, GetPosition(unit)) then
		if unit.UsePatrolAvoidChecker then
			local avoid = unit.PatrolAvoidChecker(owner, GetPosition(unit));
			if avoid then
				return Result_FireWorldEvent('PatrolAvoided', {Unit = GetObjKey(unit), Buff = buff}, unit);	
			end
		end
	end
	for i, pos in ipairs(eventArg.ApplyPositions) do
		if IsInSight(owner, pos, true) then
			SetInstantProperty(owner, 'PatrolEnemyPosition', GetPosition(eventArg.Unit));
			return Buff_Patrol_FindEnemy(owner, eventArg.Unit, nil, ds, false, nil, nil, buffType) -- 위치를 특정할 수는 있지만 굳이 넣지 않는다.
		end
	end
end
function Buff_Patrol_AbilityUsed_InSight(eventArg, buff, owner, giver, ds)
	return Buff_StartingBuff_AbilityUsed_InSight(eventArg, buff, owner, giver, ds, 'Patrol');
end
function Buff_Stand_AbilityUsed_InSight(eventArg, buff, owner, giver, ds)
	return Buff_StartingBuff_AbilityUsed_InSight(eventArg, buff, owner, giver, ds, 'Stand');
end
function Buff_Detecting_AbilityUsed_InSight(eventArg, buff, owner, giver, ds)
	return Buff_StartingBuff_AbilityUsed_InSight(eventArg, buff, owner, giver, ds, 'Detecting');
end

function Buff_StartingBuff_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.BuffName ~= buff.name then
		return;
	end
	owner.TurnPlayed = 0;
	if owner.TurnState.TurnEnded then
		-- 반 턴 정도만 미뤄진 효과를 내도록, 턴 종료 후의 Act를 보정함
		local nextAct = math.min((owner.Act + owner.Wait / 2), owner.Wait);
		ds:WorldAction(Result_TurnEnd(owner, false), false);	-- 턴 종료 이벤트 발생안시킴
		ds:WorldAction(Result_PropertyUpdated('Act', nextAct, owner, true, true));
	else
		-- 자기 턴이면 정상 턴종료
		return Result_TurnEnd(owner);
	end
end
function Buff_Patrol_BuffRemoved(eventArg, buff, owner, giver, ds)
	return Buff_StartingBuff_BuffRemoved(eventArg, buff, owner, giver, ds);
end
function Buff_Stand_BuffRemoved(eventArg, buff, owner, giver, ds)
	return Buff_StartingBuff_BuffRemoved(eventArg, buff, owner, giver, ds);
end
function Buff_Detecting_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.BuffName ~= buff.name
		or GetBuff(owner, 'Silence') then
		return;
	end
	local allPreBattleStateAllies = table.filter(GetAllUnit(GetMission(owner)), function (o)
		return IsTeamOrAlly(owner, o) and o.PreBattleState;
	end);
	local actions = {};
	for i, obj in ipairs(allPreBattleStateAllies) do
		local preBattleStateBuff = GetBuff(obj, 'Stand') or GetBuff(obj, 'Patrol') or GetBuff(obj, 'Detecting');
		(function()
			if preBattleStateBuff.name == 'Detecting' then
				return;
			end
			-- 기존에 순찰이던 친구들은 풀 시야로 검색
			local fullSightSearch = preBattleStateBuff.name == 'Patrol';
			table.insert(actions, Result_FireWorldEvent('Search', {Invoker = owner, FullSightSearch = fullSightSearch}, obj));
			if preBattleStateBuff.name == 'Stand' then
				ds:WorldAction(Result_RemoveBuff(obj, preBattleStateBuff.name), false);
				ds:WorldAction(Result_AddBuff(owner, obj, 'Patrol', 1, nil, false, false), false);
			else
				table.insert(actions, Result_RemoveBuff(obj, preBattleStateBuff.name));
			end
		end)();
	end
	owner.TurnPlayed = 0;
	if owner.TurnState.TurnEnded then
		-- 반 턴 정도만 미뤄진 효과를 내도록, 턴 종료 후의 Act를 보정함
		local nextAct = math.min((owner.Act + owner.Wait / 2), owner.Wait);
		ds:WorldAction(Result_TurnEnd(owner, false), false);	-- 턴 종료 이벤트 발생안시킴
		ds:WorldAction(Result_PropertyUpdated('Act', nextAct, owner, true, true));
	else
		-- 자기 턴이면 정상 턴종료
		table.insert(actions, Result_TurnEnd(owner));
	end
	
	if buff.DuplicateApplyChecker == 0 then
		buff.DuplicateApplyChecker = 1;
		local id = ds:Sleep(0.5);
		local camId = ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
		ds:Connect(camId, id, -1);
		ds:Connect(ds:PlayParticle(GetObjKey(owner), '_TOP_', 'Particles/Dandylion/DetectingAlertScan', 1), camId, -1);
		local message = ds:UpdateBattleEvent(GetObjKey(owner), 'GetWordAliveOnly', { Color = 'Red', Word = 'DetectEnemyAlert' });
		ds:Connect(message, camId, -1);
		local screen = ds:AlertScreenEffect(GetObjKey(owner));
		ds:Connect(screen, camId, -1);
		local endSleep = ds:Sleep(2);
		ds:Connect(endSleep, camId, -1);
		ds:TemporarySightTargetWithThisAction(GetObjKey(owner), 3, id, 0, endSleep, -1);
		table.insert(actions, Result_FireWorldEvent('PatrolDetected', {Unit=owner, Target=owner, Type='Detecting'}));
	end
	
	for _, unit in ipairs(GetAllAllyWithTeam(owner, GetOriginalTeam(owner))) do
		local aiSession = GetAISession(owner, GetTeam(unit));
		aiSession:RegisterDetectingSupportTarget(owner);
	end
	
	return unpack(actions);
end

-------------------------------- implement helper function for buff --------------------------------
if _G['BuffHelper'] == nil then
	_G['BuffHelper'] = {}
end

function BuffHelper.IsRelation(from, to, relation)
	local realRelation = GetRelation(from, to)
	return BuffHelper.IsRelationMatched(realRelation, relation);
end

function BuffHelper.IsRelationMatched(realRelation, auraRelation)
	if auraRelation == 'Team' then
		return realRelation == 'Team'
	elseif auraRelation == 'Enemy' then
		return realRelation == 'Enemy'
	elseif auraRelation == 'Ally' then
		return realRelation == 'Team' or realRelation == 'Ally'
	elseif auraRelation == 'Any' then
		return true
	else
		return false
	end
end

function BuffHelper.IsPositionInRange(pos, range)
	for _, rpos in ipairs(range) do
		if IsSamePosition(rpos, pos) then
			return true
		end
	end
	
	return false
end

function BuffHelper.GetObjectsInRange(mission, range, filterFunc, allowNonOccupyTarget, allowUntargetable)
	local objects = {}

	for _, rpos in ipairs(range) do
		if IsValidPosition(mission, rpos) then
			local testObjects = {};
			if not allowNonOccupyTarget then
				table.insert(testObjects, GetObjectByPosition(mission, rpos));
			else
				testObjects = GetAllObjectsByPosition(mission, rpos, true);
			end
			
			for _, obj in ipairs(testObjects) do
				if obj ~= nil and (allowUntargetable or not obj.Untargetable) then
					if filterFunc == nil or filterFunc(obj) then
						table.insert(objects, obj)
					end
				end
			end
		end
	end
	
	return objects
end

function BuffHelper.CalculateRangeAroundObject(obj, rangeType, pos)
	if not pos then
		pos = GetPosition(obj)

		local offset = GetInstantProperty(obj, "CreatePosOffset")
		if offset == nil then
			offset = { x = 0, y = 0 }
		end
		pos.offset = offset;
	end
	
	return CalculateRange(obj, rangeType, pos)
end

function BuffHelper.ForEachObjectInRange(obj, rangeType, pos, doFunc)
	local targetRange = BuffHelper.CalculateRangeAroundObject(obj, rangeType, pos);
	local targetObjects = BuffHelper.GetObjectsInRange(GetMission(obj), targetRange);
	
	for _, target in ipairs(targetObjects) do
		doFunc(target);
	end
end

function BuffHelper.GetAuraTargets(obj, auraName, includeDead)
	local targets = {};
	local mission = GetMission(obj);
	local auraTarget = GetInstantProperty(obj, 'AuraTarget') or {};
	local targetSet = SafeIndex(auraTarget, auraName) or {};
	for targetKey, _ in pairs(targetSet) do
		local target = GetUnit(mission, targetKey, includeDead);
		if target then
			table.insert(targets, target);
		end
	end
	return targets;
end

function BuffHelper.IsAuraTarget(obj, auraName, target)
	local targetKey = GetObjKey(target);
	local auraTarget = GetInstantProperty(obj, 'AuraTarget') or {};
	local targetSet = SafeIndex(auraTarget, auraName) or {};
	return targetSet[targetKey] ~= nil;
end
--------------------------------------------------------------------------------
function Buff_CommonAura_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.BuffName ~= buff.name then
		return;
	end
	
	local targetArgs = {};
	
	local targetRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
	local targetObjects = BuffHelper.GetObjectsInRange(GetMission(owner), targetRange, nil, buff.AuraAllowNonOccupyTarget, buff.AuraAllowUntargetable);
	
	for _, obj in pairs(targetObjects) do
		if BuffHelper.IsRelation(owner, obj, buff.AuraRelation) then
			table.insert(targetArgs, { targetUnit = obj, buffLevel = buff.Lv, moveUnit = nil, checkPos = nil, checkRange = targetRange });
		end
	end
	
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff, buff.AuraType == 'ThroughRange');
end
	
function Buff_CommonAura_UnitCreated(eventArg, buff, owner, giver, ds)
	if eventArg.Unit == owner then
		return;
	end
	if not BuffHelper.IsRelation(owner, eventArg.Unit, buff.AuraRelation) then
		return;
	end
	if not buff.AuraAllowUntargetable and eventArg.Unit.Untargetable then
		return;
	end

	local targetArgs = {};
	
	local applyRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
	local unitPos = eventArg.Position;
	
	if BuffHelper.IsPositionInRange(unitPos, applyRange) then
		table.insert(targetArgs, { targetUnit = eventArg.Unit, buffLevel = buff.Lv, moveUnit = nil, checkPos = nil, checkRange = applyRange });		
	end
	
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff, buff.AuraType == 'ThroughRange');
end

function Buff_CommonAura_BuffRemoved_InRange(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.BuffName ~= buff.name then
		return;
	end
	
	local actions = {};
	
	local prevObjects = BuffHelper.GetAuraTargets(owner, buff.name);
	
	local targetArgs = {};

	for _, obj in pairs(prevObjects) do
		if BuffHelper.IsRelation(owner, obj, buff.AuraRelation) then
			table.insert(targetArgs, { targetUnit = obj, buffLevel = -buff.Lv });		
		end
	end
	
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);

	-- kill owner of this buff
	if buff.AuraOwnerKill then
		table.insert(actions, Result_Damage(99999999, 'Normal', 'Hit'));
	end
	
	return unpack(actions);
end

function Buff_CommonAura_BuffRemoved_ThroughRange(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.BuffName ~= buff.name then
		return;
	end

	local actions = {};
	
	-- kill owner of this buff
	if buff.AuraOwnerKill then
		table.insert(actions, Result_Damage(99999999, 'Normal', 'Hit'));
	end
	
	return unpack(actions);
end

function Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, auraName, buffName, instant)
	local buffCls = GetClassList('Buff')[buffName];
	if not buffCls then
		return;
	end

	-- ObjKey 기반의 레퍼런스 카운팅
	local ownerKey = GetObjKey(owner);
	targetArgs = table.filter(targetArgs, function(targetArg)
		local target = targetArg.targetUnit;
		local targetKey = GetObjKey(target);
		local immune, reason = BuffImmunityTest(buffCls, target);
		
		-- 걸린 놈의 레퍼런스 갱신
		local auraBuff = GetInstantProperty(target, 'AuraBuff') or {};
		local ownerSet = SafeIndex(auraBuff, buffName) or {};
		if targetArg.buffLevel > 0 and not immune then
			ownerSet[ownerKey] = {Aura = auraName, Level = targetArg.buffLevel};
		elseif targetArg.buffLevel < 0 then
			ownerSet[ownerKey] = nil;
		end
		if not table.empty(ownerSet) then
			auraBuff[buffName] = ownerSet;
		else
			auraBuff[buffName] = nil;
		end
		SetInstantProperty(target, 'AuraBuff', auraBuff);
		
		-- 건 놈의 레퍼런스 갱신
		local auraTarget = GetInstantProperty(owner, 'AuraTarget') or {};
		local targetSet = SafeIndex(auraTarget, auraName) or {};
		if targetArg.buffLevel > 0 and not immune then
			targetSet[targetKey] = {Buff = buffName, Level = targetArg.buffLevel};
		elseif targetArg.buffLevel < 0 then
			targetSet[targetKey] = nil;
		end
		if not table.empty(targetSet) then
			auraTarget[auraName] = targetSet;
		else
			auraTarget[auraName] = nil;
		end
		SetInstantProperty(owner, 'AuraTarget', auraTarget);

		local nextBuffLv = 0;
		for _, set in pairs(ownerSet) do
			-- 기존에 저장된 인스턴스 프로퍼티에 대한 하위 호환 처리
			local setLv = (type(set) == 'table') and set.Level or set;
			nextBuffLv = math.max(nextBuffLv, setLv);
		end
		
		local targetBuff = GetBuff(target, buffName);
		if nextBuffLv > 0 and (targetBuff == nil or targetBuff.Lv ~= nextBuffLv or targetBuff.Life < 1000) then
			targetArg.buffLevel = nextBuffLv;
			return true;
		elseif nextBuffLv == 0 and targetBuff ~= nil then
			targetArg.buffLevel = -1 * targetBuff.Lv;
			return true;
		else
			return false;
		end
	end);
	
	local modifier = function (buff)
		buff.UseAddedMessage = false;
		if not instant then
			buff.IsAuraSlave = true;
		end
	end
	
	for _, targetArg in ipairs(targetArgs) do
		local subActions = {};
		if not instant then
			InsertBuffActionsModifier(subActions, giver, targetArg.targetUnit, buffName, targetArg.buffLevel, 99999, nil, modifier, false, {Type = 'Aura', Value = buffName});
		else
			InsertBuffActions(subActions, giver, targetArg.targetUnit, buffName, targetArg.buffLevel, nil, modifier, false, {Type = 'Aura', Value = buffName});
		end
		
		local immune, reason = BuffImmunityTest(buffCls, targetArg.targetUnit);
		if #subActions > 0 and (reason ~= 'Hidden' or targetArg.buffLevel < 0) then
			local ownerKey = GetObjKey(owner);
			local targetKey = GetObjKey(targetArg.targetUnit);
			local connectCmd = nil;
			if targetArg.moveUnit and targetArg.checkPos and IsValidPosition(owner, targetArg.checkPos) then
				local moveUnitKey = GetObjKey(targetArg.moveUnit);
				local eventCmd = ds:SubscribeFSMEvent(moveUnitKey, 'StepForward', 'CheckUnitArrivePosition', {CheckPos = targetArg.checkPos}, true);
				ds:SetConditional(eventCmd);
				connectCmd = eventCmd;
			else
				connectCmd = ds:Sleep(0);
				ds:SetCommandLayer(connectCmd, game.DirectingCommand.CM_SECONDARY);
				ds:SetContinueOnNormalEmpty(connectCmd);
			end
			
			if targetArg.buffLevel > 0 and buffCls.UseAddedMessage then
				if targetArg.checkRange then
					for _, pos in ipairs(targetArg.checkRange) do
						local particleID = ds:PlayParticlePosition('Particles/Dandylion/Selection_AssistRange', pos.x, pos.y, pos.z, 1, true, true);
						ds:Connect(particleID, connectCmd, -1);
					end
				end
				
				local detectedMessage = connectCmd;
				if not immune then
					detectedMessage = ds:UpdateBattleEvent(targetKey, 'BuffInvoked', { Buff = buffName })
					ds:Connect(detectedMessage, connectCmd, -1);
				end
				connectCmd = detectedMessage;
			end
			
			for _, action in pairs(subActions) do
				local actionCmd = ds:WorldAction(action, true);
				if actionCmd > 0 and connectCmd then
					ds:Connect(actionCmd, connectCmd);
				end
			end
		end
	end
end

function Buff_CommonAura_MoveCommon_InRange_Self(targetArgs, buff, owner, startPos, endPos)
	local rangeObjects = {};	
	
	-- 시작 지점에서 범위 내에 있던 오브젝트들을 기록
	local prevObjects = BuffHelper.GetAuraTargets(owner, buff.name);

	for _, obj in ipairs(prevObjects) do
		if obj ~= owner and BuffHelper.IsRelation(owner, obj, buff.AuraRelation) then
			local unitKey = GetObjKey(obj);
			if rangeObjects[unitKey] == nil then
				rangeObjects[unitKey] = { object = obj, endInRange = false };
			end
			rangeObjects[unitKey].prevInRange = true;
		end
	end
	
	-- 종료 지점에서 범위 내에 있던 오브젝트들을 기록
	local endRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange, endPos);
	local endObjects = BuffHelper.GetObjectsInRange(GetMission(owner), endRange, nil, buff.AuraAllowNonOccupyTarget, buff.AuraAllowUntargetable);
	
	for _, obj in ipairs(endObjects) do
		if obj ~= owner and BuffHelper.IsRelation(owner, obj, buff.AuraRelation) then
			local unitKey = GetObjKey(obj);
			if rangeObjects[unitKey] == nil then
				rangeObjects[unitKey] = { object = obj, prevInRange = false };				
			end
			rangeObjects[unitKey].endInRange = true;
		end
	end

	-- 탐색된 오브젝트 정보들을 가지고 버프가 변경되어야 하는 대상들을 추출
	for unitKey, info in pairs(rangeObjects) do
		if info.prevInRange and (not info.endInRange) then
			table.insert(targetArgs, { targetUnit = info.object, buffLevel = -buff.Lv, moveUnit = owner, checkPos = endPos, checkRange = endRange });		
		elseif (not info.prevInRange) and info.endInRange then
			table.insert(targetArgs, { targetUnit = info.object, buffLevel = buff.Lv, moveUnit = owner, checkPos = endPos, checkRange = endRange });
		end
	end
	
	-- 뭔가의 이유로 자기 자신이 안 걸려있으면 걸어주자
	if BuffHelper.IsRelation(owner, owner, buff.AuraRelation) and not HasBuff(owner, buff.AuraBuff.name) then
		local ownerPos = GetPosition(owner);
		local ownerRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange, ownerPos);
		local ownerInRange = BuffHelper.IsPositionInRange(ownerPos, ownerRange);
		if ownerInRange then
			table.insert(targetArgs, { targetUnit = owner, buffLevel = buff.Lv, moveUnit = owner, checkPos = endPos, checkRange = endRange });
		end
	end
end

function Buff_CommonAura_MoveCommon_InRange(targetArgs, buff, owner, mover, startPos, endPos)
	local isRelation = BuffHelper.IsRelation(owner, mover, buff.AuraRelation);
	if not isRelation then
		return;
	end

	local applyRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);

	local prevInRange = BuffHelper.IsAuraTarget(owner, buff.name, mover);
	local endInRange = BuffHelper.IsPositionInRange(endPos, applyRange);
	
	if prevInRange and (not endInRange) then
		table.insert(targetArgs, { targetUnit = mover, buffLevel = -buff.Lv, moveUnit = mover, checkPos = endPos, checkRange = applyRange });			
	elseif (not prevInRange) and endInRange then
		table.insert(targetArgs, { targetUnit = mover, buffLevel = buff.Lv, moveUnit = mover, checkPos = endPos, checkRange = applyRange });		
	end
end

function Buff_CommonAura_DeadCommon_InRange(targetArgs, buff, owner, mover, isDead)
	local isRelation = BuffHelper.IsRelation(owner, mover, buff.AuraRelation);
	if not isRelation then
		return;
	end

	local applyRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
	local curPos = GetPosition(mover);
	local curInRange = BuffHelper.IsPositionInRange(curPos, applyRange);
	
	if isDead and curInRange then
		table.insert(targetArgs, { targetUnit = mover, buffLevel = -buff.Lv, moveUnit = mover });
	elseif (not isDead) and curInRange then
		table.insert(targetArgs, { targetUnit = mover, buffLevel = buff.Lv, moveUnit = mover });
	end
end

function Buff_CommonAura_UnitMoved_InRange_Self(eventArg, buff, owner, giver, ds)
	if IsDead(owner) then		-- 사망에 의한 처리는 거기서 되었을거임ㅇㅇ
		return;
	end
	local startPos = eventArg.Path[1];
	local endPos = eventArg.Position;
	
	-- 탐색된 오브젝트 정보들을 가지고 버프가 변경되어야 하는 대상들을 추출
	local targetArgs = {};	
	Buff_CommonAura_MoveCommon_InRange_Self(targetArgs, buff, owner, startPos, endPos);

	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end

function Buff_CommonAura_UnitMoved_InRange_Others(eventArg, buff, owner, giver, ds)
	if eventArg.Unit.Untargetable then
		return;
	end
	-- 자기 자신의 이동은 Self 핸들러에 처리한다.
	local myMove = (eventArg.Unit == owner);
	if myMove then
		return;
	end
	
	local isRelation = BuffHelper.IsRelation(owner, eventArg.Unit, buff.AuraRelation);
	if not isRelation then
		return;
	end

	local startPos = eventArg.Path[1];
	local endPos = eventArg.Position;
	local mover = eventArg.Unit;
	
	local targetArgs = {};
	Buff_CommonAura_MoveCommon_InRange(targetArgs, buff, owner, mover, startPos, endPos);

	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end

function Buff_CommonAura_UnitPositionChanged_InRange(eventArg, buff, owner, giver, ds)
	if eventArg.Unit == owner or eventArg.Unit.Untargetable then
		return;
	end

	local startPos = eventArg.BeginPosition;
	local endPos = eventArg.Position;
	local mover = eventArg.Unit;
	
	local targetArgs = {};
	Buff_CommonAura_MoveCommon_InRange(targetArgs, buff, owner, mover, startPos, endPos);
	
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end
function Buff_CommonAura_UnitPositionChanged_Self_InRange(eventArg, buff, owner, giver, ds)
	if IsDead(owner) then
		return;
	end
	local startPos = eventArg.BeginPosition;
	local endPos = eventArg.Position;
	
	local targetArgs = {};
	Buff_CommonAura_MoveCommon_InRange_Self(targetArgs, buff, owner, startPos, endPos);
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end

function Buff_CommonAura_UnitMoveStarted_ThroughRange(eventArg, buff, owner, giver, ds)
	if eventArg.Unit.Untargetable then
		return;
	end

	local myMove = (eventArg.Unit == owner);
	if (not myMove) and (not BuffHelper.IsRelation(owner, eventArg.Unit, buff.AuraRelation)) then
		return;
	end
	
	local targetArgs = {};

	if myMove then
		local rangeObjects = {};
		
		-- 시작 지점에서 범위 내에 있던 오브젝트들은 따로 처리가 필요하므로 별도로 마킹한다.
		local startPos = eventArg.Path[1];
		local startRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange, startPos);
		local startObjects = BuffHelper.GetObjectsInRange(GetMission(owner), startRange, nil, buff.AuraAllowNonOccupyTarget, buff.AuraAllowUntargetable);

		for _, obj in ipairs(startObjects) do
			if obj ~= owner and BuffHelper.IsRelation(owner, obj, buff.AuraRelation) then
				local unitKey = GetObjKey(obj);
				if rangeObjects[unitKey] == nil then
					rangeObjects[unitKey] = { object = obj, startInRange = true, checkPos = startPos, checkRange = startRange };				
				end
			end
		end
	
		-- 이동하면서 범위 내에 들어온 오브젝트들은 최초 시점의 위치를 기록한다.
		for i = 2, #eventArg.Path do
			local pos = eventArg.Path[i];
			local applyRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange, pos);
			local applyObjects = BuffHelper.GetObjectsInRange(GetMission(owner), applyRange, nil, buff.AuraAllowNonOccupyTarget, buff.AuraAllowUntargetable);
		
			for _, obj in ipairs(applyObjects) do
				if obj ~= owner and BuffHelper.IsRelation(owner, obj, buff.AuraRelation) then
					local unitKey = GetObjKey(obj);
					if rangeObjects[unitKey] == nil then
						rangeObjects[unitKey] = { object = obj, startInRange = false, checkPos = pos, checkRange = applyRange };				
					end
				end
			end
		end	
	
		-- 시작 지점에서 범위 내에 있던 오브젝트들은 이동 전에 이미 걸린 상태이므로, 대상에서 제외한다.
		for unitKey, info in pairs(rangeObjects) do
			if (not info.startInRange) then
				table.insert(targetArgs, { targetUnit = info.object, buffLevel = buff.Lv, moveUnit = owner, checkPos = info.checkPos, checkRange = info.checkRange });
			end
		end
	else
		local applyRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
	
		local startPos = eventArg.Path[1];
		local startInRange = BuffHelper.IsPositionInRange(startPos, applyRange);
	
		local targetPos = nil;

		for _, pos in ipairs(eventArg.Path) do
			if BuffHelper.IsPositionInRange(pos, applyRange) then
				targetPos = pos;
				break;
			end
		end
		
		if targetPos ~= nil and (not startInRange) then
			table.insert(targetArgs, { targetUnit = eventArg.Unit, buffLevel = buff.Lv, moveUnit = eventArg.Unit, checkPos = targetPos, checkRange = applyRange });		
		end
	end
	
	-- 걸릴 위치 정보 기록
	local auraThrough = GetInstantProperty(owner, 'AuraThrough') or {};
	local ownerSet = SafeIndex(auraThrough, buff.name) or {};
	
	local posMap = {};
	for _, targetArgs in ipairs(targetArgs) do
		local pos = targetArgs.checkPos;	
		local posKey = string.format('%d,%d,%d', pos.x, pos.y, pos.z);
		SafeInsert(posMap, posKey, targetArgs);
	end
	
	ownerSet[eventArg.MoveIdentifier] = posMap;
	auraThrough[buff.name] = ownerSet;
	SetInstantProperty(owner, 'AuraThrough', auraThrough);
end
function Buff_CommonAura_UnitMovedSingleStep_ThroughRange(eventArg, buff, owner, giver, ds)
	if eventArg.Unit.Untargetable then
		return;
	end
	-- 걸릴 위치 정보 가져오기
	local auraThrough = GetInstantProperty(owner, 'AuraThrough') or {};
	local ownerSet = SafeIndex(auraThrough, buff.name) or {};
	local posMap = SafeIndex(ownerSet, eventArg.MoveIdentifier);
	if posMap == nil then
		return;
	end
	local pos = eventArg.Position;
	local posKey = string.format('%d,%d,%d', pos.x, pos.y, pos.z);
	local targetArgs = SafeIndex(posMap, posKey);
	if targetArgs == nil then
		return;
	end
	-- 버프 걸기
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff, true);
end
function Buff_CommonAura_UnitMoved_ThroughRange(eventArg, buff, owner, giver, ds)
	if eventArg.Unit.Untargetable then
		return;
	end
	-- 걸릴 위치 정보 정리
	local auraThrough = GetInstantProperty(owner, 'AuraThrough') or {};
	local ownerSet = SafeIndex(auraThrough, buff.name) or {};
	ownerSet[eventArg.MoveIdentifier] = nil;
	auraThrough[buff.name] = ownerSet;
	SetInstantProperty(owner, 'AuraThrough', auraThrough);
end

function Buff_CommonAura_UnitPositionChanged_ThroughRange(eventArg, buff, owner, giver, ds)
	if eventArg.Unit.Untargetable then
		return;
	end

	local myMove = (eventArg.Unit == owner);
	if (not myMove) and (not BuffHelper.IsRelation(owner, eventArg.Unit, buff.AuraRelation)) then
		return;
	end
	
	local targetArgs = {};

	if myMove then
		-- 이동하면서 범위 내에 들어온 오브젝트들은 최초 시점의 위치를 기록한다.
		local pos = eventArg.Position;
		local applyRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange, pos);
		local applyObjects = BuffHelper.GetObjectsInRange(GetMission(owner), applyRange, nil, buff.AuraAllowNonOccupyTarget, buff.AuraAllowUntargetable);
	
		for _, obj in ipairs(applyObjects) do
			if obj ~= owner and BuffHelper.IsRelation(owner, obj, buff.AuraRelation) then
				if not HasBuff(obj, buff.AuraBuff) then
					table.insert(targetArgs, { targetUnit = obj, buffLevel = buff.Lv, moveUnit = owner, checkPos = pos, checkRange = applyRange });
				end
			end
		end
	else
		local applyRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
	
		local targetPos = nil;

		if BuffHelper.IsPositionInRange(eventArg.Position, applyRange) then
			table.insert(targetArgs, { targetUnit = eventArg.Unit, buffLevel = buff.Lv, moveUnit = eventArg.Unit, checkPos = eventArg.Position, checkRange = applyRange });
		end
	end
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff, true);
end

function Buff_CommonAura_UnitDead_InRange_Self(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	local targetArgs = {};
	
	local targetObjects = BuffHelper.GetAuraTargets(owner, buff.name);	
	for _, obj in pairs(targetObjects) do
		table.insert(targetArgs, { targetUnit = obj, buffLevel = -buff.Lv });		
	end
	
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end

function Buff_CommonAura_UnitResurrect_InRange_Self(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	local targetArgs = {};
	
	local targetRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
	local targetObjects = BuffHelper.GetObjectsInRange(GetMission(owner), targetRange, nil, buff.AuraAllowNonOccupyTarget, buff.AuraAllowUntargetable);
	
	for _, obj in pairs(targetObjects) do
		if BuffHelper.IsRelation(owner, obj, buff.AuraRelation) then
			table.insert(targetArgs, { targetUnit = obj, buffLevel = buff.Lv, moveUnit = owner, checkPos = GetPosition(owner), checkRange = targetRange });					
		end
	end
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end

function Buff_CommonAura_UnitDead_InRange(eventArg, buff, owner, giver, ds)
	if eventArg.Unit.Untargetable then
		return;
	end
	local targetArgs = {};
	Buff_CommonAura_DeadCommon_InRange(targetArgs, buff, owner, eventArg.Unit, true);
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end

function Buff_CommonAura_UnitResurrect_InRange(eventArg, buff, owner, giver, ds)
	if eventArg.Unit.Untargetable then
		return;
	end
	local targetArgs = {};
	Buff_CommonAura_DeadCommon_InRange(targetArgs, buff, owner, eventArg.Unit, false);
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end
-- 제자리에서 적용 대상만 갱신함
function Buff_CommonAura_SightRangeChanged(eventArg, buff, owner, giver, ds)
	if eventArg.Buff.SightRange == 0 then
		return;
	end
	local ownerPos = GetPosition(owner);
	local targetArgs = {};	
	Buff_CommonAura_MoveCommon_InRange_Self(targetArgs, buff, owner, ownerPos, ownerPos);
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end

function Buff_CommonAura_InvalidateAuraTarget(eventArg, buff, owner, giver, ds)
	return _Buff_CommonAura_InvalidateAuraTarget(eventArg, buff, owner, giver, ds);
end
function _Buff_CommonAura_InvalidateAuraTarget(eventArg, buff, owner, giver, ds)
	local ownerKey = GetObjKey(owner);
	local auraBuff = GetInstantProperty(eventArg.Unit, 'AuraBuff') or {};
	local ownerSet = SafeIndex(auraBuff, buff.AuraBuff) or {};
	local prevInSet = ownerSet[ownerKey];

	-- 뭔가의 이유로 대상 버프가 사라졌을 떄의 처리
	if prevInSet and not HasBuff(eventArg.Unit, buff.AuraBuff) then
		prevInSet = false;
		ownerSet[ownerKey] = nil;
		auraBuff[buff.AuraBuff] = ownerSet;
		SetInstantProperty(eventArg.Unit, 'AuraBuff', auraBuff);
	end
	
	-- 이미 걸린 것도 아니고 새로 걸릴 대상도 아니면, 범위 체크 없이 바로 종료
	local isRelation = BuffHelper.IsRelation(owner, eventArg.Unit, buff.AuraRelation);
	if not prevInSet and not isRelation then
		return;
	end
	
	local endPos = GetPosition(eventArg.Unit);
	
	local targetArgs = {};
	local applyRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
	local endInRange = BuffHelper.IsPositionInRange(endPos, applyRange);
	local auraBuffImmuned = BuffImmunityTest(GetClassList('Buff')[buff.AuraBuff], eventArg.Unit);
	
	if prevInSet and (not endInRange or auraBuffImmuned or not isRelation) then
		table.insert(targetArgs, { targetUnit = eventArg.Unit, buffLevel = -buff.Lv, moveUnit = eventArg.Unit, checkPos = endPos, checkRange = applyRange });
	elseif not prevInSet and (endInRange and isRelation) then
		table.insert(targetArgs, { targetUnit = eventArg.Unit, buffLevel = buff.Lv, moveUnit = eventArg.Unit, checkPos = endPos, checkRange = applyRange });
	end
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end
function Buff_AuraSlave_InvalidateAuraTarget(eventArg, buff, owner, giver, ds)
	local nextLevel = 0;
	
	local auraBuff = GetInstantProperty(owner, 'AuraBuff');
	local ownerSet = SafeIndex(auraBuff, buff.name) or {};
	for objKey, data in pairs(ownerSet) do
		if not HasBuff(GetUnit(GetMissionID(owner), objKey), data.Aura) then	-- 오라 주인의 버프가 없어짐
			ownerSet[objKey] = nil;
		else
			nextLevel = math.max(nextLevel, data.Level);
		end
	end
	auraBuff[buff.name] = ownerSet;
	SetInstantProperty(owner, 'AuraBuff', auraBuff);
	
	if nextLevel > 0 then
		return;
	end
	
	return Result_RemoveBuff(owner, buff.name);
end
function Buff_AuraUtil_GetAuraTargets(owner, auraBuff)
	local auraTarget = GetInstantProperty(owner, 'AuraTarget') or {};
	local targetSet = SafeIndex(auraTarget, auraBuff.name) or {};
	local ret = {};
	local mission = GetMission(owner);
	for objKey, _ in pairs(targetSet) do
		table.insert(ret, GetUnit(mission, objKey));
	end
	return ret;
end
--------------------------------------------------------------------------------
function Buff_ActionController_TurnStart(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local shotTargetKey = buff.AutoUseAbilityTarget;
	local autoUseAbility = buff.AutoUseAbility;
	buff.AutoUseAbility = 'None';
	buff.AutoUseAbilityTarget = 'None';
	local target = GetUnit(GetMission(owner), shotTargetKey);
	if not target or autoUseAbility == 'None' then	-- 대상이 없어짐
		return Result_TurnEnd(owner);	-- 그냥 턴 종료
	end
	return Result_TurnEnd(owner), Result_UseAbility(owner, autoUseAbility, GetPosition(target));
end

function Buff_ActionController_TakeDamage(eventArg, buff, owner, giver, ds)
	-- 공격받으면 풀릴 것인가?
	-- 일단 귀찮으니 냅둬
end
function Buff_ModifyAbility_Apply(owner)
	local abilities = GetAllAbility(owner, false, true);
	local actions = {};
	for _, ability in ipairs(abilities) do
		local stashData = StashAbilityForApplyModifier(ability);
		ResetObject(ability);
		ApplyAbilityStashedData(ability, stashData);
		Shared_ApplyAbilityModifier(ability, owner);
		table.insert(actions, Result_SynchronizeAbility(owner, ability.name));
	end
	return unpack(actions);
end
function Buff_ModifyAbility_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	return Buff_ModifyAbility_Apply(owner);
end
function Buff_ModifyAbility_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	return Buff_ModifyAbility_Apply(owner);
end
function Buff_InvalidateFieldEffect_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	return Result_FireWorldEvent('InvalidateBuffAffectorTarget', {Unit = owner});
end
function Buff_InvalidateFieldEffect_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	return Result_FireWorldEvent('InvalidateBuffAffectorTarget', {Unit = owner});
end
function Buff_ImmuneDebuff_BuffGroup_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	local actions = {};
	for _, group in ipairs(buff.ImmuneDebuff_BuffGroup) do
		local buffList = GetBuffType(owner, 'Debuff', nil, group.name);
		for _, rb in ipairs(buffList) do
			InsertBuffActions(actions, owner, owner, rb.name, -rb.Lv, true);
			ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = rb.name, EventType = 'Ending' });
		end
	end
	return unpack(actions);
end
---------------------------------------------------------------------------------------------
-- 개별 이벤트 핸들러
--------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- 유닛 턴 시작 [UnitTurnStart]
-------------------------------------------------------------------------------
-- 항동결 수액
---@param eventArg unitTurnEndEventArg
---@param buff any
---@param owner unit
---@param giver any
---@param ds any
function Buff_AntiFreezingInfusionSolution_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local company = GetCompany(owner);
	if not company then
		return;
	end
	local testBuffLv = buff and buff.Lv or 0;
	if testBuffLv < buff.Base_ApplyAmount2[1] then
		local msgType = 'MasteryBuffCountMessage';
		if testBuffLv <= 0 then
			msgType = 'MasteryBuffCountMessage_Zero';
		end
		local formatTable = { BuffName = ClassDataText('Buff', buff.name, 'Title'), BuffLv = testBuffLv };
		ds:ShowFrontmessageWithText(FormatMessageText(GuideMessageText(msgType), formatTable), 'Corn', GetTeam(owner));
		buff.Base_ApplyAmount2[1] = testBuffLv;
	end
end
-- 과부하 시스템
---@param eventArg unitTurnEndEventArg
---@param buff any
---@param owner unit
---@param giver any
---@param ds any
function Buff_SecondWind_MindAndBody_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if HasBuff(owner, 'Exhaustion') then
		return;
	end
	local prevTurnEndTime = buff.DuplicateApplyChecker;
	buff.DuplicateApplyChecker = GetMissionElapsedTime(owner);
	if owner.TurnPlayed == 0 or owner.ActModified then
		owner.ActModified = false;
		return;
	end

	local overload = 36 - (buff.DuplicateApplyChecker - prevTurnEndTime) - buff.Base_ApplyAmount[1] * 12;

	if overload == 0 then
		return;
	end

	local actions = {};
	AddActionOverloadForDS(actions, owner, overload, true, true, ds);
	return unpack(actions);
end
-- 도발
function Buff_Provocation_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local aggroTarget = GetInstantProperty(owner, 'AggroTarget');
	local pos = GetPosition(aggroTarget);
	if pos ~= nil and not IsDead(aggroTarget) and IsEnemy(owner, aggroTarget) then
		return;
	end
	return Result_RemoveBuff(owner, buff.name, true, owner);
end
-- 야수
function Buff_Subordinate_UnitTurnStartTest(owner, giver)
	if not IsDead(giver) then
		return false;
	end
	
	local mid = GetMissionID(owner);
	local team = GetTeam(owner, true);
	local teamCount = GetTeamCount(mid, team, false, true);
	for i = 1, teamCount do
		local obj = GetTeamUnitByIndex(mid, team, i, false, true);
		if obj and not GetInstantProperty(obj, 'Subordinate') then
			return false;
		end
	end
	
	-- 남은 팀원이 모두 Subordinate 유닛들임..
	return true;
end
function Buff_SummonBeast_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if not Buff_Subordinate_UnitTurnStartTest(owner, giver) then
		return;
	end
	
	local actions = {};
	ApplyUnsummonBeastActions(actions, giver, owner);
	return unpack(actions);
end
function Buff_SummonMachine_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if not Buff_Subordinate_UnitTurnStartTest(owner, giver) then
		return;
	end
	
	local actions = {};
	ApplyUnsummonMachineActions(actions, giver, owner);
	return unpack(actions);	
end
-- 안정 (시민)
function Buff_Civil_Stabilized_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local playerExist = false;
	local enemyExist = false;
	for _, obj in ipairs(GetNearObject(owner, 4.4)) do
		if obj ~= owner then
			if GetTeam(obj) == 'player' then
				playerExist = true;
			end
			if GetRelation(obj, 'player') == 'Enemy' then
				enemyExist = true;
			end
		end
	end
	
	if playerExist or not enemyExist then
		return;
	end
	
	buff.Life = 0;
	return Result_RemoveBuff(owner, buff.name);
end
-- 연막 생성기
function Buff_Generator_Smoke_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local malfunction = RandomTest(5);
	if not malfunction then
		return Buff_Generator_Smoke_Activate(owner, GetPosition(owner));
	end
	
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name));
	ds:UpdateBattleEvent(GetObjKey(owner), 'Malfunction');
	return unpack(actions);
end
-- 코스트 소모하는 로직.
function Buff_CostEater_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local actions = {};
	if not table.find(buff.UseTurnStartCostEaterType, owner.CostType.name) then
		return unpack(actions);
	end	
	local addCost = buff.UseTurnStartCostAmount;
	-- 증가부분.
	if addCost > 0 then
		local nextCost, reasons = AddActionCost(actions, owner, addCost, true);
		if owner.Cost < nextCost then
			ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = nextCost - owner.Cost });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	elseif owner.Cost + addCost >= 0 then
		local _, reasons = AddActionCost(actions, owner, addCost, true);
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = addCost });
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
	-- 코스트 모자라면 지운다.
	if buff.IsRemoveBuffByCostEater and owner.Cost + addCost < 0 then 
		table.insert(actions, Result_RemoveBuff(owner, buff.name));
	end
	return unpack(actions);
end
-- SP 소모하는 로직.
function Buff_SPEater_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local actions = {};
	local addSP = buff.UseTurnStartSPAmount;
	if addSP > 0 then
		-- 증가부분.
		AddSPPropertyActionsObject(actions, owner, addSP, true, ds, true);
	elseif addSP < 0 then
		if owner.Overcharge > 0 then -- 과충전 상태에선 공짜!
			addSP = 0;
		end
		-- 감소부분.
		if addSP < 0 and owner.SP + addSP >= 0 then
			AddSPPropertyActionsObject(actions, owner, addSP, true, ds, true);
		end
		-- 코스트 모자라면 지운다.
		if buff.IsRemoveBuffBySPEater and owner.SP + addSP < 0 then 
			table.insert(actions, Result_RemoveBuff(owner, buff.name));
			ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
		end
	end
	return unpack(actions);
end
-- 완전 엄폐물.
function Buff_CoverableObject_UnitTurnStarted(eventArg, buff, owner, giver, ds)
	local applies = {};
	if not IsControllable(owner) then
		local adjustAllyCount = table.count(GetNearObject(owner, 1.4), function(o) return owner ~= o and IsTeamOrAlly(owner, o) and o.Coverable; end);
		if adjustAllyCount > 0 then
			table.insert(applies, Result_TurnEnd(owner, true));
		end
	end
	return unpack(applies);
end
-- 자폭
function Buff_SuicideBomb_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local objKey = GetObjKey(owner);
	local aniID = ds:PlayAni(objKey, 'AstdIdle', false, -1, true);
	ds:SetCommandLayer(aniID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(aniID);
	
	local actions = {Result_RemoveBuff(owner, buff.name)};
	local deadEvent = {Object = owner, EventType='Dead', Args = {EventType='SingularPoint'}};
	table.append(actions, {Buff_FlameExplosion_Activated(buff, 'FlameExplosion', owner, owner, ds, {deadEvent})});
	table.insert(actions, Result_DestroyObject(owner, true, true));
	table.insert(actions, Result_PropertyUpdated('HP', 0, owner, false, true));
	return unpack(actions);
end
-- 불신, 원망
function Buff_Distrust_UnitTurnStart(eventArg, buff, owner, ds, returnBuff)
	buff.DuplicateApplyChecker = buff.DuplicateApplyChecker + 1;
	
	if buff.DuplicateApplyChecker >= 3 then
		ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
		ds:ShowFrontmessageWithText(GuideMessageText('CivilTrustPlayerAgain'));
		return Result_RemoveBuff(owner, buff.name), Result_AddBuff(owner, owner, returnBuff, 1);
	end
end
function Buff_DistrustRescue_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local returnBuff = 'Rescue';
	if GetInstantProperty(owner, 'CitizenType') == 'Unrest' then
		returnBuff = 'Civil_Unrest';
	end
	return Buff_Distrust_UnitTurnStart(eventArg, buff, owner, ds, returnBuff);
end
function Buff_InjuredRageRescue_UnitTurnStart(eventArg, buff, owner, giver, ds)
	return Buff_Distrust_UnitTurnStart(eventArg, buff, owner, ds, 'InjuredRescue');
end
-- 화합물 만들기
function Buff_MakeConcoction_UnitTurnStart(eventArg, buff, owner, giver, ds)	
	local addLevel = 1;
	local mastery_ShakeShake = GetMasteryMastered(GetMastery(owner), 'ShakeShake');
	if mastery_ShakeShake then
		addLevel = addLevel + mastery_ShakeShake.ApplyAmount2;
		MasteryActivatedHelper(ds, mastery_ShakeShake, owner, 'UnitTurnStart_Self');
	end
	-- 황금에 대한 열정
	local mastery_PassionForGold = GetMasteryMastered(GetMastery(owner), 'PassionForGold');
	if mastery_PassionForGold then
		addLevel = addLevel + mastery_PassionForGold.ApplyAmount2;
		MasteryActivatedHelper(ds, mastery_PassionForGold, owner, 'UnitTurnStart_Self');
	end
	
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.AddBuff, addLevel, true);
	return unpack(actions);
end
function Buff_LostSoul_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local nearObjects = table.filter(GetNearObject(owner, buff.ApplyAmount), function(o) 
		return o ~= owner and IsInSight(owner, o) and not o.Obstacle and GetRelation(owner, o) ~= 'None' and o.Race.Life;
	end);
	local nearest = nil;
	local nearestDist = nil;
	for _, obj in ipairs(nearObjects) do
		local dist = GetDistanceFromObjectToObject(owner, obj);
		if nearestDist == nil or dist < nearestDist then
			nearestDist = dist;
			nearest = obj;
		end
	end
	if nearest == nil then
		return;
	end
	
	local force = nil;
	local buffSource = nil;
	local battleEvent = '';
	if IsEnemy(owner, nearest) then
		force = 'SoulCurse';
		buffSource = 'Buff_Negative';
		battleEvent = 'SoulCurse';
	elseif IsAllyOrTeam(owner, nearest) then
		force = 'SoulAscension';
		buffSource = 'Buff_Positive';
		battleEvent = 'SoulAscension';
	end
	
	if force == nil then
		return;
	end
	
	local buffPicker = RandomBuffPicker.new(nearest, Linq.new(GetClassList(buffSource))
		:select(function(pair) return pair[1]; end)
		:toList());
	
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.name, -buff.Lv);
	local ownerKey = GetObjKey(owner);
	local targetKey = GetObjKey(nearest);
	
	local cam = ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false);
	ds:Connect(ds:UpdateBattleEvent(ownerKey, battleEvent, {}), cam, 0.5);
	
	local firstForce = nil;
	for i = 1, buff.Lv do
		local buffName = buffPicker:PickBuff();
		if buffName then
			local f = ds:ForceEffect(ownerKey, '_CENTER_', targetKey, '_CENTER_', force);
			InsertBuffActions(actions, owner, nearest, buffName, 1);
			actions[#actions]._ref = f;
			actions[#actions]._ref_offset = -1;
			if firstForce then
				ds:Connect(f, firstForce, 0);
			else
				firstForce = f;
			end
		end
	end
	return unpack(actions);
end
function Buff_Death_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	if buff.Life == 0 then
		return;
	end
	local actions = {};
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffRemainTurn', { Buff = buff.name, Remain = buff.Life });
	return unpack(actions);
end
function Buff_Solo_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	local actions = {};
	local unitCount = GetTeamCount(GetMissionID(owner), GetTeam(owner));
	if unitCount > 1 then
		InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.Lv);
	end
	return unpack(actions);
end
function Buff_Anger_IsEnableAnger(owner)
	if IsDead(owner) then
		return false;
	end
	if GetBuff(owner, 'Patrol') or GetBuff(owner, 'Stand') then
		return false;
	end	
	if GetActionController(owner) ~= 'None' then
		return false;
	end
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return false;
	end
	return true;
end
function Buff_Anger_FindAngerTargets(owner)
	local allBattleEnemies = table.filter(GetNearObject(owner, owner.SightRange), function(unit)
		local citizenType = GetInstantProperty(unit, 'CitizenType');
		return IsEnemy(owner, unit) and not GetBuff(unit, 'Patrol') and not GetBuff(unit, 'Stand') and not citizenType;
	end);
	local allUnit = GetAllUnitInSight(owner, true);
	local allCitizens = table.filter(allUnit, function(unit)
		local citizenType = GetInstantProperty(unit, 'CitizenType');
		return citizenType ~= nil and citizenType ~= 'Child';
	end);
	
	local ownerPos = GetPosition(owner);
	-- 시야 6칸 안에 적이 한명이라도 있으면 발동하지 않음
	for _, unit in ipairs(allBattleEnemies) do
		local unitPos = GetPosition(unit);
		if GetDistance3D(ownerPos, unitPos) <= 7 then
			return {};
		end
	end
	
	return table.filter(allCitizens, function(unit)
		local unitPos = GetPosition(unit);
		local distanceUnitToOwner = GetDistance3D(ownerPos, unitPos);
		-- 4칸 시민이 없으면 무시
		if GetDistance3D(ownerPos, unitPos) > 4 then
			return false;
		end
		-- 주변 4칸 내에 적이 있는 시민들은 무시
		for _, enemy in ipairs(allBattleEnemies) do
			local enemyPos = GetPosition(enemy);
			local distanceEnemyToOwner = GetDistance3D(ownerPos, enemyPos);
			local distanceUnitToEnemy = GetDistance3D(unitPos, enemyPos);
			if distanceUnitToEnemy <= 4 or distanceEnemyToOwner <= distanceUnitToOwner then
				return false;
			end
		end
		return true;
	end);
end
function Buff_Anger_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	-- 기본 조건 체크
	if not Buff_Anger_IsEnableAnger(owner) then
		return;
	end
	-- 대상 체크
	local targets = Buff_Anger_FindAngerTargets(owner);
	if #targets == 0 then
		return;
	end

	local targetObjKeySet = {};
	for _, target in ipairs(targets) do
		targetObjKeySet[GetObjKey(target)] = true;
	end
	
	SetObjectLoseIFF(owner, true);
	
	-- 이동 어빌리티 사용
	local abilities = GetAvailableAbility(owner);
	local moveAbility = nil;
	for _, ability in ipairs(abilities) do	
		if ability.name == 'Move' then
			moveAbility = ability;
			break;
		end
	end
	
	local moveStrategy = function(self, adb)
		-- 대상이 공격 불가능한 곳은 가지 않는다.
		if not adb.TargetAttackable then
			return -1;
		end
		return (1000 / adb.TargetDistance - adb.MoveDistance / 100);
	end

	local moveTarget = nil;
	local movePosition = nil;
	if moveAbility then
		local prevPos = GetPosition(owner);
		-- 대상 중에 하나라도 공격이 가능한 위치가 있으면, 그 위치로 이동한다.
		for _, target in ipairs(table.shuffle(targets)) do
			local pos, score = FindAIMovePosition(owner, abilities, moveStrategy, {SelfSightOnly = true, CitizenOnly = true, Target = target}, {});
			if score ~= nil and score >= 0 and not IsSamePosition(pos, prevPos) then
				moveTarget = target;
				movePosition = pos;
				break;
			end
		end
		if movePosition then
			local moveAction = Result_UseAbility(owner, moveAbility.name, movePosition);
			ds:WorldAction(moveAction, true);
		end
	end
	
	-- 이동 후 조건 체크
	if movePosition and not Buff_Anger_IsEnableAnger(owner) then
		SetObjectLoseIFF(owner, false);
		return;
	end

	-- 공격 어빌리티 선택
	local attackStrategy = function(self, adb)
		-- CitizenOnly을 설정했는데, 굳이 또 체크해야 하나?
		if not adb.IsCitizen or adb.IsCitizen == 0 then
			return -1;
		end
		-- 대상들 중에 없으면 무시
		if not targetObjKeySet[GetObjKey(adb.Object)] then
			return -1;
		end
		local priority = 1;
		-- 이동 시의 대상이 있으면, 그 외 대상은 가중치를 낮춤
		if moveTarget and not adb.IsTarget then
			priority = 0.1;
		end
		return NearFirstAttackAI(self, adb) * priority;
	end;
	
	-- 이동 시 대상이 있으면 그걸 쓰고, 없으면 말고...
	local usingAbility, usingPos, _, score = FindAIMainAction(owner, GetAvailableAbility(owner), {{Strategy = attackStrategy, Target = 'Attack'}}, {SelfSightOnly = true, CitizenOnly = true, Target = moveTarget}, {});
	if not usingAbility or score < 0 then
		SetObjectLoseIFF(owner, false);
		return;
	end

	-- 공격 어빌리티 사용
	local battleEvent = {{Object = owner, EventType = 'Anger'}};
	local attackAction = Result_UseAbility(owner, usingAbility.name, usingPos, {BattleEvents = battleEvent});
	
	local startID = ds:Sleep(0);
	local attackID = ds:WorldAction(attackAction, true);
	ds:Connect(attackID, startID, -1);
	
	local ownerPos = GetPosition(owner);
	ds:TemporarySightWithThisAction(ownerPos, 3, startID, 0, attackID, -1);
	ds:TemporarySightWithThisAction(usingPos, 3, startID, 0, attackID, -1);
	
	SetObjectLoseIFF(owner, false);
end
function Buff_ConditionalAnger_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	-- 이미 화가 나있음
	if GetBuff(owner, 'Anger') then
		return;
	end
	-- 언제 어떻게 되었는지 모르겠지만, 현재 HP가 꽉 차있으면 화가 안 남...
	if owner.HP >= owner.MaxHP then
		return;
	end
	-- 기본 조건 체크
	if not Buff_Anger_IsEnableAnger(owner) then
		return;
	end
	-- 대상 체크
	local targets = Buff_Anger_FindAngerTargets(owner);
	if #targets == 0 then
		return;
	end
	-- Anger 버프를 걸어주고, Anger 버프의 턴 시작 이벤트 핸들러를 수동으로 1번 실행해줌
	ds:WorldAction(Result_AddBuff(owner, owner, 'Anger', 1));
	Buff_Anger_UnitTurnStart(eventArg, buff, owner, giver, ds);
end
function Buff_Civil_Child_Rescue_UnitTurnStart(eventArg, buff, owner, giver, ds)
	ds:UpdateBalloonCivilMessage(GetObjKey(owner), 'Feared', owner.Info.AgeType);
end
function Buff_WitchTrick_UnitTurnStart(buff, owner, ds, mainSource, sparseSource)
	local source = RandomTest(95) and mainSource or sparseSource;
	local goodBuffList = Linq.new(GetClassList(source))
		:select(function(pair) return pair[1]; end)
		:toList();
	local buffPicker = RandomBuffPicker.new(owner, goodBuffList);
	local changeBuff = buffPicker:PickBuff();
	
	local actions = {};
	InsertBuffActions(actions, owner, owner, changeBuff, 1, true);
	table.insert(actions, Result_RemoveBuff(owner, buff.name));
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', {Buff = buff.name});
	return unpack(actions);
end
function Buff_WitchCurse_UnitTurnStart(eventArg, buff, owner, giver, ds)
	return Buff_WitchTrick_UnitTurnStart(buff, owner, ds, 'Buff_Negative', 'Buff_Positive');
end
function Buff_WitchBless_UnitTurnStart(eventArg, buff, owner, giver, ds)
	return Buff_WitchTrick_UnitTurnStart(buff, owner, ds, 'Buff_Positive', 'Buff_Negative');
end
function Buff_Taming_UnitTurnStart(eventArg, buff, owner, giver, ds)
	-- 길들이기 대상만 핸들링
	local tamingTargetKey = GetInstantProperty(owner, 'TamingTarget');
	if GetObjKey(eventArg.Unit) ~= tamingTargetKey then
		return;
	end
	local mission = GetMission(owner);
	local tamingTarget = GetUnit(mission, tamingTargetKey);
	if tamingTarget == nil then
		return;
	end
	-- 충성적인 대상에게만 발동
	if not HasBuff(tamingTarget, 'BeastLoyaltyGood') then
		return;
	end
	-- 소환된 녀석만 핸들링
	local summonMasterKey = GetInstantProperty(tamingTarget, 'SummonMaster');
	if summonMasterKey == nil then
		return;
	end
	local summonMaster = GetUnit(mission, summonMasterKey);
	if summonMaster == nil then
		return;
	end
	-- 소환자가 시야 내에 있어야
	if not IsInSight(tamingTarget, GetPosition(summonMaster), true) then
		return;
	end
	local actions = {};
	ds:EnableTemporalSightTarget(summonMasterKey, 0, 1);
	ds:ChangeCameraTarget(summonMasterKey, '_SYSTEM_', false, false);
	ds:UpdateBattleEvent(summonMasterKey, 'TamingFailedSummoner', {});
	ds:LookAt(summonMasterKey, tamingTargetKey, true);
	ds:PlayAni(summonMasterKey, 'Overcharge', false, -1, true);
	ds:Sleep(0.5);
	ApplyTamingFailedActions(actions, owner, tamingTarget, ds);
	ds:DisableTemporalSightTarget(summonMasterKey, 0);
	return unpack(actions);
end
-- 안개 장막
function Buff_MistShield_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local debuffList = GetBuffType(owner, 'Debuff');
	if #debuffList == 0 then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'BuffInvoked', { Buff = buff.name });
	for _, debuff in ipairs(debuffList) do
		table.insert(actions, Result_RemoveBuff(owner, debuff.name, true));
		ds:UpdateBattleEvent(objKey, 'BuffDischarged', { Buff = debuff.name });
	end
	local applyAmount = math.floor(#debuffList / buff.ApplyAmount) * buff.ApplyAmount2;
	if applyAmount > 0 then
		local addHP = math.floor(owner.MaxHP * applyAmount/100);
		local reasons = {};
		addHP, reasons = AddActionRestoreHP(actions, owner, owner, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		DirectDamageByType(ds, owner, 'HPRestore', -addHP, math.min(owner.MaxHP, owner.HP + addHP), true, false);
		AddBuffDamageChat(ds, owner, buff, -1 * addHP);
	end
	return unpack(actions);
end
-- 휘감는 안개
function Buff_EntanglingMists_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local buffList = GetBuffType(owner, 'Buff');
	if #buffList == 0 then
		return;
	end
	local picker = RandomPicker.new(false);
	for _, buff in ipairs(buffList) do
		picker:addChoice(1, buff);
	end
	local removeBuffList = picker:pickMulti(buff.ApplyAmount);
	if #removeBuffList == 0 then
		return;
	end
	-- 버프 해제 면역
	local immuneMastery = GetMasteryMasteredImmuneRemoveBuff(GetMastery(owner));
	if immuneMastery then
		MasteryActivatedHelper(ds, immuneMastery, owner, 'ImmuneRemoveBuff');
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'BuffInvoked', { Buff = buff.name });
	for _, buff in ipairs(removeBuffList) do
		table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
		ds:UpdateBattleEvent(objKey, 'BuffDischarged', { Buff = buff.name });
	end
	return unpack(actions);
end
-- 얼어붙는 피
function Buff_FrozenBlood_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if buff.Lv < buff:MaxStack(owner) then
		return;
	end
	local damage = owner.HP;
	local realDamage, reasons = ApplyDamageTest(owner, damage, 'Buff');
	local isDead = owner.HP <= realDamage;
	local remainHP = math.clamp(owner.HP - realDamage, 0, owner.MaxHP);
	local connectID = DirectDamageByType(ds, owner, 'FrozenBlood', damage, remainHP, true, isDead);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons, connectID, 0);
	return Result_Damage(damage, 'Normal', 'Hit', owner, owner, 'Buff', 'Etc', buff);
end
-- 열등감, 위축
function Buff_MaxStackAddBuff_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if buff.Lv < buff:MaxStack(owner) then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.Lv, true);
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	return unpack(actions);
end
-- 부화 중인 야샤알
function Buff_HatchedObjectYasha_UnitTurnStart(eventArg, buff, owner, giver, ds)
	local hatchingCount = GetInstantProperty(owner, 'HatchingCount') or 1;
	return Buff_HatchedObjectYasha_DoHatching(ds, owner, hatchingCount);
end
function Buff_HatchedObjectYasha_DoHatching(ds, owner, hatchingCount)
	local monType = GetInstantProperty(owner, 'HatchingMonster');
	if not monType then
		return;
	end
	local team = GetInstantProperty(owner, 'HatchingTeam') or GetTeam(owner);
	local range = GetInstantProperty(owner, 'HatchingRange') or 'Sphere4';
	local aiType = GetInstantProperty(owner, 'HatchingAI') or 'NormalMonsterAI';
	
	-- 부화 위치 픽커
	local mission = GetMission(owner);
	local ownerPos = GetPosition(owner);
	local targetRange = table.filter(CalculateRange(owner, range, ownerPos), function(pos)
		return not GetObjectByPosition(mission, pos) and not IsSamePosition(ownerPos, pos);
	end);
	
	local posPicker = RandomPicker.new(false);
	for _, pos in ipairs(targetRange) do
		local dist = GetDistance3D(ownerPos, pos);
		local score = math.floor(1000 / math.max(dist, 1));
		posPicker:addChoice(score, pos);
	end
	
	local objKey = GetObjKey(owner);
	local sleepID = ds:Sleep(0);
	
	local actions = {};
	-- HatchingCount 마리 부화
	for i = 1, hatchingCount do
		local newObjKey = GenerateUnnamedObjKey(mission);
		local movePos = posPicker:pick();
		if not movePos then
			break;
		end
		
		local unitInitializeFunc = function(unit, arg)
			UNIT_INITIALIZER(unit, unit.Team);
		end;
		
		local createAction = Result_CreateMonster(newObjKey, monType, ownerPos, team, unitInitializeFunc, {}, aiType, {}, true);
		ApplyActions(mission, { createAction }, false);
		local target = GetUnit(mission, newObjKey);
		if not target then
			break;
		end
		
		local moveID = ds:Move(newObjKey, movePos, false, false, 'Amove', 0, 0, false, 1, false, false, true, true);
		local moveAction = Result_Move(movePos, target);
		moveAction._ref = moveID;
		moveAction._ref_offset = 0;
		moveAction.directing_id = moveID;
		moveAction.mission_direct_move = true;
		moveAction.no_zoc = true;
		ds:WorldAction(moveAction, false);
		ds:Connect(moveID, sleepID, 0);
		
		-- 대기
		local allyList = GetTargetInRangeSight(target, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSight(target, 'Sight', 'Enemy', true);
		local battleAllyExist = table.exist(allyList, function(obj)
			return not obj.PreBattleState and obj.name ~= owner.name;
		end);
		if #enemyList == 0 and not battleAllyExist then
			InsertBuffActions(actions, target, target, 'Stand', 1, true);
		end
	end
	
	return unpack(actions);
end
-- 반항적
function Buff_BeastLoyaltyBad_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	local buff_Arbitrary = GetBuff(owner, buff.AddBuff);
	local actionProb = buff_Arbitrary and math.floor(buff_Arbitrary.Lv / buff.ApplyAmount) * buff.ApplyAmount2 or 0;
	if not RandomTest(actionProb) then
		return;
	end
	local mission = GetMission(owner);
	local ownerPos = GetPosition(owner);
	-- 행동 패턴 1~4
	local aiPattern = math.random(1, 4);
	local target = nil;
	if aiPattern == 1 then
		-- 소환자
		local summonMaster = GetInstantProperty(owner, 'SummonMaster');
		if summonMaster ~= nil then
			target = GetUnit(mission, summonMaster);
		end
	elseif aiPattern == 2 then
		-- 가장 먼 적
		target = Linq.new(GetAllUnitInSight(owner, false))
			:where(function(o) return owner ~= o and IsEnemy(owner, o); end)
			:orderByDescending(function(o) return GetDistance3D(ownerPos, GetPosition(o)); end)
			:first();
	end	
	-- 이동 AI
	local abilities = GetAvailableAbility(owner, false);
	if aiPattern == 4 then
		-- 성능 상의 이유로 단일 대상 공격만 허용
		abilities = table.filter(abilities, function(ability)
			return IsMoveTypeAbility(ability) or (ability.Type == 'Attack' and ability.TargetType == 'Single');
		end);
	end
	local moveAbility = FindMoveAbilityInList(abilities);
	if moveAbility and owner.Movable then
		local moveStrategy = nil;
		if aiPattern == 1 or aiPattern == 2 then
			-- 대상과 거리 가까운 곳
			moveStrategy = function(self, adb, args)
				return 1000 - adb.TargetDistance;
			end;
		elseif aiPattern == 3 then
			-- 아군도 적고, 적군도 적은 곳
			moveStrategy = function(self, adb, args)
				return 1000 - adb.AllyDensity(4) - adb.Dangerous + adb.MinEnemyDistance;
			end;
		elseif aiPattern == 4 then
			-- 공격 가능 대상 중에 거리가 가장 먼 적이 있는 곳
			-- 을 해야겠지만, 어떻게 구현을 해야할 지 잘 모르겠어서 비슷한 느낌으로 돌아가게 아래 방식으로 구현했음
			-- 적을 공격 가능한 곳 중에서 거리가 가장 먼 곳으로 가서 근처에 아무나 공격하면 되지 않을까?
			moveStrategy = function(self, adb, args)
				if not adb.Attackable then
					return -982;
				end
				return 1000 + adb.MoveDistance;
			end
		end
		
		local movePos = nil;
		local prevPos = GetPosition(owner);
		local pos, score = FindAIMovePosition(owner, abilities, moveStrategy, {NoneBlock=true, Target=target}, {});
		if score ~= nil and score >= 0 and not IsSamePosition(pos, prevPos) then
			movePos = pos;
		end
		if movePos then
			local moveAction = Result_UseAbility(owner, moveAbility.name, movePos, {}, true, {NoCamera = true});
			ds:WorldAction(moveAction, true);
		end
	end

	local startID = ds:Sleep(0);
	ds:SetCommandLayer(startID, game.DirectingCommand.CM_SECONDARY);
	local prevID = startID;
	
	-- 공격 어빌리티 사용
	if aiPattern == 4 and GetBuffStatus(owner, 'Attackable', 'And') then
		local usingAbility, usingPos, _, score = FindAIMainAction(owner, abilities, {{Strategy = NearFirstAttackAI, Target = 'Attack'}}, {SelfSightOnly = true, NoIndirect = true}, {});
		if usingAbility and score >= 0 then
			local attackAction = Result_UseAbility(owner, usingAbility.name, usingPos, {}, true, {NoCamera = true});
			local attackID = ds:WorldAction(attackAction, true);
			if attackID ~= -1 then
				ds:Connect(attackID, prevID, -1);
				prevID = attackID;
			end
		end
	end

	-- 턴 종료
	if not IsDead(owner) then
		local turnEndAction = Result_TurnEnd(owner);
		local turnEndID = ds:WorldAction(turnEndAction, true);
		ds:Connect(turnEndID, prevID, -1);
	end
end
-- 은신
function Buff_Stealth_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if buff.Life > 1 or buff.Life <= 0 then
		return;
	end
	ds:ShowFrontmessageWithText(GameMessageFormText({ Type = 'StateReleaseAlert', State = buff.name }, 'Corn'), 'Corn', GetTeam(owner));
end
----------------------------------------------------------------------------
-- 유닛 턴 종료 [UnitTurnEnd]
----------------------------------------------------------------------------
-- 감염
function Buff_Infection_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	local nearObjects = GetNearObject(owner, 1.4);
	local actions = {};
	for _, o in ipairs(nearObjects) do
		if o ~= owner and RandomTest(buff.ApplyAmount2) then
			InsertBuffActions(actions, owner, o, buff.name, 1, true);
		end
	end
	return unpack(actions);
end
-- 과부하
function Buff_SecondWind_MindAndBody_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if owner.TurnState.ExtraActable or owner.TurnState.ExtraAttackable or owner.TurnState.ExtraMovable then
		buff.Base_ApplyAmount[1] = 1;
	elseif owner.TurnState.UsedMainAbility then
		buff.Base_ApplyAmount[1] = 0
	elseif not owner.TurnState.Moved then
		buff.Base_ApplyAmount[1] = 2;
	else
		buff.Base_ApplyAmount[1] = 1;
	end
end
-- 매복중
function Buff_BurrowOverwatching_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded then
		return;
	end
	local target = eventArg.Unit;
	local targetPos = GetPosition(target);
	if not IsInSight(owner, targetPos, true) or IsDead(target) then
		return;
	end
	local removeBuff = Result_RemoveBuff(owner, buff.name);
	local burrowAmbush = FindAbility(owner, 'BurrowAmbush');
	if burrowAmbush == nil then
		return removeBuff;
	end
	local range = CalculateRange(owner, burrowAmbush.TargetRange, GetPosition(owner));
	local canHit = BuffHelper.IsPositionInRange(targetPos, range);
	if not canHit then
		return;
	end	
	local targetAble, targetReasonList = TargetAbilityUseableCheck(owner, burrowAmbush, target);
	if targetAble ~= 'Able' then
		return;
	end
	local ambushAction = Result_UseAbilityTarget(owner, burrowAmbush.name, target, {ReactionAbility=true, BattleEvents={{Object = owner, EventType = 'BurrowAmbush', Args = nil}}}, true, {});
	ambushAction.free_action = true;
	return ambushAction, removeBuff;
end
function Buff_Escape_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	return Result_DirectingScript(function(mid, ds, args)
		return Result_RemoveBuff(owner, buff.name);
	end, nil, true, true);
end
function Buff_SelfTurnEndRemove_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.Lv);
	return unpack(actions);
end
function Buff_DetectingWatchtower_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	buff.DuplicateApplyChecker = 0;
end
function Buff_MotherNatureRage_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	buff.DuplicateApplyChecker = 0;
end
function Buff_Outlaw_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	buff.DuplicateApplyChecker = 0;
end
function Buff_ChangingMind_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	return Result_RemoveBuff(owner, buff.name);
end
function Buff_Trance_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if buff.Age >= 10 then
		ds:UpdateAchievement('AbilityRayTrance', true, GetTeam(owner));
	end
end
function Buff_ContinuousAttack_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	buff.DuplicateApplyChecker = 0;
end
-- 부식독
function Buff_CorrosionPoison_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	InsertBuffActions(actions, owner, owner, buff.AddBuff2, 1, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	return unpack(actions);
end
function Buff_Lava_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner
		or buff.Disabled then
		return;
	end
	local actions = {};
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	InsertBuffActions(actions, owner, owner, buff.AddBuff2, 1, true);
	return unpack(actions);
end
function Buff_InformationSharing_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	return Result_UpdateInstantProperty(owner, buff.name, {});
end
-- 냉정
function Buff_DeadlyCalm_UnitTurnEnd(eventArg, buff, owner, giver, ds)
	if buff.DuplicateApplyChecker == 0 then
		return;
	end
	return Result_RemoveBuff(owner, buff.name);
end
--------------------------------------------------------------------------------
-- 유닛 턴 획득 [UnitTurnAcquired]
----------------------------------------------------------------------------
-- 마음의 눈 사용 중
function UsingBeholderVision2_UnitTurnAcquired(eventArg, buff, owner, giver, ds)
	-- 뭔가의 이유로 참조 대상의 유효하지 않으면 버프 해제
	local target = GetUnit(owner, buff.ReferenceTarget);
	if target and HasBuff(target, 'BeholderVision2') then
		return;
	end
	return Result_RemoveBuff(owner, buff.name);
end
--------------------------------------------------------------------------------
-- 유닛사망 [UnitDead]
----------------------------------------------------------------------------
-- 안정 (시민)
function Buff_Civil_Stabilized_UnitDead(eventArg, buff, owner, giver, ds)
	if GetTeam(eventArg.Unit) ~= 'player' then
		return;
	end
	buff.Life = 0;
	return Result_RemoveBuff(owner, buff.name);
end
-- 제어권 획득
function Buff_ControlTakeover_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner and eventArg.Unit ~= giver then
		return;
	end
	local actions = {};
	if eventArg.Unit == owner then
		-- 자신의 사망 시 제어권 획득 대상에서 해제됨
		if giver then
			local ctots = GetInstantProperty(giver, 'ControlTakingOverTargets') or {};
			ctots = table.filter(ctots, function(ctot) return ctot ~= GetObjKey(owner) end);
			table.insert(actions, Result_UpdateInstantProperty(giver, 'ControlTakingOverTargets', ctots));
		end
		table.insert(actions, Result_FireWorldEvent('FriendlyMachineAboutToLeave', {Machine = owner, MasterKey = giver and GetObjKey(giver) or nil}));
	else
		-- 바로 부활했으면 해제 안 됨
		if IsDead(giver) then
			-- giver 사망으로 제어권 획득이 해제됨 (버프 해제 이벤트에서 알아서 위의 로직도 적용됨)
			table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
		end
	end
	return unpack(actions);
end
function buff_UnderControl_UnitDead(eventArg, buff, owner, giver, ds)
	SetInstantProperty(giver, 'ControlTarget', nil);
end
function Buff_Rescue_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	if eventArg.Killer ~= nil then
		if eventArg.Killer == owner or eventArg.Killer.Info.name == 'Void' or eventArg.Killer.Info.Title == '' then
			ds:ShowFrontmessageWithText(GuideMessageText('CivilOutOfActionFromVoid'), 'Corn');
		else
			ds:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('CivilOutOfAction'), {MonName = ClassDataText('ObjectInfo', eventArg.Killer.Info.name, 'Title')}), 'Corn');
		end
	end
	return Result_FireWorldEvent('CitizenRescueFailed', {Unit=owner, Savior = eventArg.Killer});
end
function Direct_FakeRescueRevealDead(mid, ds, args)
	local owner = args.Owner;
	local killer = args.Killer;
	
	local sleepID = ds:Sleep(3);
	local playSoundID = nil;
	local massageID = nil;
	if GetTeam(killer) == 'player' then
		playSoundID = ds:PlaySound('Success.wav', 'Layout', 1);
		massageID = ds:UpdateInteractionMessage(GetObjKey(killer), 'Rescue', killer.Info.name);
	elseif killer then
		playSoundID = ds:PlaySound('Fail.wav', 'Layout', 1);
		massageID = ds:UpdateInteractionMessage(GetObjKey(killer), 'RescueFailed', killer.Info.name);
	end
	ds:Connect(playSoundID, massageID, 0.5);
	ds:Connect(sleepID, massageID, 0);	
end
function Buff_FakeRescueRevealed_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local eventName = nil;
	if GetTeam(eventArg.Killer) == 'player' then
		eventName = 'CitizenRescued';
	else
		eventName = 'CitizenRescueFailed';
	end
	return Result_FireWorldEvent(eventName, {Unit=owner, Savior=eventArg.Killer}), Result_DirectingScript('Direct_FakeRescueRevealDead', {Owner = owner, Killer=eventArg.Killer});
end
function Buff_Watchtower_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local deadTowerInitializer = function(tower, args)
		SetInstantProperty(tower, 'MonsterType', 'Watchtower_Destroyed');
		UNIT_INITIALIZER(tower, tower.Team, {Patrol = false});
		InitializeWatchtower('Destroyed', tower);
	end;
	return Result_CreateMonster(GenerateUnnamedObjKey(owner), 'Watchtower_Destroyed', GetPosition(owner), '_neutral_', deadTowerInitializer, nil, 'DoNothingAI', nil, true);
end
function Buff_SuppressionTarget_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner
		or eventArg.Unit.HP > 0 then
		return;
	end
	local actions = {};
	table.insert(actions, Result_PropertyUpdated('IsHeadDisplay', false, owner, false));
	table.insert(actions, Result_BuffPropertyUpdated('Untargetable', true, owner, buff.name, false, nil, true));
	table.insert(actions, Result_ChangeTeam(owner, '_neutral_'));
	table.insert(actions, Result_Resurrect(owner, 'Faint'));
	local interaction = Result_UpdateInteraction(owner, 'Arrest', true);
	interaction.sequential = true;
	table.insert(actions, interaction);
	return unpack(actions);
end
function Buff_CarryingBodies_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner 
		or eventArg.Unit.HP > 0 then
		return;
	end
	local carryingBody = GetInstantProperty(owner, buff);
	if carryingBody == nil then
		return;
	end
	local pos = GetPosition(owner);
	ds:Move(GetObjKey(carryingBody), pos, true);
end
function Buff_Bloodwalker_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Killer ~= owner 
		or buff.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or not IsEnemy(owner, eventArg.Unit) then
		return;
	end
	
	buff.DuplicateApplyChecker = 1;
	local actions = {};
	local addHP = math.floor(owner.MaxHP * buff.ApplyAmount/100);
	local reasons = {};
	addHP, reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	DirectDamageByType(ds, owner, 'BloodWalker', -addHP, math.min(owner.MaxHP, owner.HP + addHP), true, false);
	AddBuffDamageChat(ds, owner, buff, -1 * addHP);
	return unpack(actions);
end
function Buff_Hero_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Killer ~= owner 
		or buff.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or not IsEnemy(owner, eventArg.Unit) then
		return;
	end
	
	buff.DuplicateApplyChecker = 1;
	local actions = {};
	local hasteAct = buff.ApplyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, -hasteAct, 'Friendly', true);
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWaitCustomEvent', {Time = -hasteAct, EventType = 'Ending'});
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
function Buff_ClimbWeb_UnitDead(eventArg, buff, owner, giver, ds)
	-- 죽었다가 부활한 상황이면, 부활 핸들러에서 처리한다.
	if not IsDead(owner) then
		return;
	end
	local prevProps = GetInstantProperty(owner, 'ClimbWeb');
	if not prevProps then
		return;
	end
	local actions = {};
	if prevProps.DummyObjKey ~= nil then
		local mission = GetMission(owner);
		local dummyObj = GetUnit(mission, prevProps.DummyObjKey);
		if dummyObj then
			table.insert(actions, Result_DestroyObject(dummyObj, false, false));
		end
		prevProps.DummyObjKey = nil;
		SetInstantProperty(owner, 'ClimbWeb', prevProps);
	end
	return unpack(actions);
end
function Buff_Burrow_UnitDead(eventArg, buff, owner, giver, ds)
	-- 죽었다가 부활한 상황이면, 부활 핸들러에서 처리한다.
	if not IsDead(owner) then
		return;
	end
	local prevProps = GetInstantProperty(owner, 'Burrow');
	if not prevProps then
		return;
	end
	local actions = {};
	if prevProps.DummyObjKey ~= nil then
		local mission = GetMission(owner);
		local dummyObj = GetUnit(mission, prevProps.DummyObjKey);
		if dummyObj then
			table.insert(actions, Result_DestroyObject(dummyObj, false, false));
		end
		prevProps.DummyObjKey = nil;
		SetInstantProperty(owner, 'Burrow', prevProps);
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 유닛 부활
function Buff_ConditionalAnger_UnitResurrect(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	
	local actions = {};
	-- 죽었다가 부활한 놈이니 무조건 화를 낸다.
	if not GetBuff(owner, 'Anger') then
		InsertBuffActions(actions, owner, owner, 'Anger', 1);
	end
	
	return unpack(actions);
end
function Buff_ClimbWeb_UnitResurrect(eventArg, buff, owner, giver, ds)
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	return unpack(actions);
end
function Buff_Burrow_UnitResurrect(eventArg, buff, owner, giver, ds)
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	return unpack(actions);
end
function Buff_FlameExplosion_Activated(buff, flameAbility, expTaker, target, ds, additionalBattleEvents)
	local flameExplosionInitializer = function(sprayObject, args)
		SetInstantProperty(sprayObject, 'MonsterType', 'Explosion');
		if expTaker then
			SetExpTaker(sprayObject,GetExpTaker(expTaker));
		end
		UNIT_INITIALIZER(sprayObject, sprayObject.Team, {Patrol = false});
	end;
	
	local usingPos = GetPosition(target);

	local mission = GetMission(target);
	local explosionObjKey = GenerateUnnamedObjKey(mission);
	local createAction = Result_CreateMonster(explosionObjKey, 'Explosion', usingPos, '_neutral_',  flameExplosionInitializer, {}, 'DoNothingAI', nil, true);
	ApplyActions(mission, { createAction }, false);
	local explosionObj = GetUnit(mission, explosionObjKey);
	-- 터지는 오브젝트의 MaxHP 비례 데미지 때문에, 생성된 오브젝트의 Base_MaxHP를 원본 오브젝트의 MaxHP로 덮어씀
	explosionObj.Base_MaxHP = target.MaxHP;
	InvalidateObject(explosionObj);
	local battleEvents={{Object = explosionObj, EventType = 'BuffInvokedFromAbility', Args = {Buff = buff.name, EventType = 'Beginning', NoEffect = true}}};
	if additionalBattleEvents then
		table.append(battleEvents, additionalBattleEvents);
	end
	return Result_DirectingScript(function(mid, ds, args)
		local abilityUse = Result_UseAbility(explosionObj, flameAbility, usingPos, {BattleEvents = battleEvents}, true);
		abilityUse.sequential = true;
		
		return abilityUse, Result_DestroyObject(explosionObj, false, true)
	end, nil, true, true);
end
function Buff_FireShield_Unitdead(eventArg, buff, owner, giver, ds)
	return Buff_FlameExplosion_Activated(buff, buff.ExplosionType, eventArg.Killer, owner);
end
function Buff_Taming_UnitDead(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'TamingTarget');
	if (eventArg.Unit ~= owner and GetObjKey(eventArg.Unit) ~= targetKey) then
		return;
	end
	local target = nil;
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	local actions = {};
	ApplyTamingFailedActions(actions, owner, target, ds);
	table.insert(actions, Result_FireWorldEvent('TamingFailed', {Unit=owner, Target=target}));
	return unpack(actions);
end
function Buff_Communicating_UnitDead(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'CommunicatingTarget');
	if (eventArg.Unit ~= owner and GetObjKey(eventArg.Unit) ~= targetKey) then
		return;
	end
	local target = nil;
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	local actions = {};
	ApplyCommunicatingFailedActions(actions, owner, target, ds);
	table.insert(actions, Result_FireWorldEvent('CommunicatingFailed', {Unit=owner, Target=target}));
	return unpack(actions);
end
function Buff_SummonBeast_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner and eventArg.Unit ~= giver then
		return;
	end
	local unit = eventArg.Unit;
	return Result_DirectingScript(function(mid, ds, args)
		-- 부활로 인해 핸들링 시점에 안 죽고 살아있으면 무시
		if unit == owner and not IsDead(owner) then
			return;
		end
		if unit == giver and not IsDead(giver) then
			return;
		end
		local actions = {};
		if unit == giver then
			-- Brainwashing 상태이면 무시
			if GetBuffStatus(owner, 'Brainwashing', 'Or') then
				return;
			end
			ApplySummonBeastStandAloneActions(actions, owner, giver);
		else
			ApplyUnsummonBeastActions(actions, giver, owner);
		end	
		return unpack(actions);
	end, nil, true, true);
end
function ApplySummonBeastStandAloneActions(actions, owner, giver)
	if giver == nil then
		local masterKey = GetInstantProperty(owner, 'SummonMaster');
		if masterKey then
			giver = GetUnit(GetMission(owner), masterKey, true);
		end
	end
	local mastery_StandAloneTraining = GetMasteryMastered(GetMastery(owner), 'StandAloneTraining');
	local buff_BeastLoyaltyGood = GetBuff(owner, 'BeastLoyaltyGood');
	if mastery_StandAloneTraining or buff_BeastLoyaltyGood then
		if buff_BeastLoyaltyGood then
			InsertBuffActions(actions, owner, owner, buff_BeastLoyaltyGood.AddBuff, 1, true);
			AddSPPropertyActionsObject(actions, owner, owner.MaxSP);
		end
	else
		ApplyUnsummonBeastActions(actions, giver, owner);
	end
	return unpack(actions);
end
function Buff_SummonMachine_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner and eventArg.Unit ~= giver then
		return;
	end
	-- 부활로 인해 핸들링 시점에 안 죽고 살아있으면 무시
	if not IsDead(owner) and not IsDead(giver) then
		return;
	end
	-- Brainwashing 상태이면 무시
	if eventArg.Unit == giver and GetBuffStatus(owner, 'Brainwashing', 'Or') then
		return;
	end	
	local actions = {};
	ApplyUnsummonMachineActions(actions, giver, owner);
	return unpack(actions);
end
function Buff_RepairInteraction_UnitDead(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'RepairTarget');
	if (eventArg.Unit ~= owner and GetObjKey(eventArg.Unit) ~= targetKey) then
		return;
	end
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	table.insert(actions, Result_PropertyUpdated('Act', 0, owner, true, true));
	return unpack(actions);
end
-- 각인
function Buff_Imprinting_UnitDead(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'AggroTarget');
	if (eventArg.Unit ~= owner and GetObjKey(eventArg.Unit) ~= targetKey) then
		return;
	end
	local actions = {};
	-- 적이 아니면 공격을 하려고 해도 못하니, 그냥 바로 일반 전투 AI로...
	if eventArg.Unit == owner and IsEnemy(owner, eventArg.Killer) then
		InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
		-- 도발 AI를 재탕
		SetMonsterAIInfo(owner, 'ProvocationAI', {});
		SetInstantProperty(owner, 'AggroTarget', GetObjKey(eventArg.Killer));
	else
		SetMonsterAIInfo(owner, 'NormalMonsterAI', {});
		SetInstantProperty(owner, 'AggroTarget', nil);
	end
	return unpack(actions);
end
-- 주시
function Buff_BeholderVision_UnitDead(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= giver then
		return;
	end
	return Result_RemoveBuff(owner, buff.name, true);
end
function Buff_BeholderVision_UnitDeadSelf(eventArg, buff, owner, giver, ds)
	return Result_SightSharing(owner, GetTeam(giver), false, true);
end
-- 무력화 시스템
function Buff_OutOfActionSystem_UnitDead(eventArg, buff, owner, giver, ds)
	-- 의도적으로 UnitDead_Self가 아니라 UnitDead로 구현되었음
	-- 타인 부활 능력(ex. 긴급 구조 프로그램, 닌자 구급함 등)보다 늦게 처리되지만,
	-- 하지만 NormalUnitDead 같은 시스템 글로벌 트리거보다 먼저 처리되어야 되므로
	if eventArg.Unit ~= owner then
		return;
	end
	if not IsDead(owner) then
		return;
	end
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	local resurrectID = ds:Resurrect(objKey, false, true);
	local hpUpdate = Result_PropertyUpdated('HP', 0, owner, true);
	hpUpdate.sequential = true;
	local actions = {};
	table.insert(actions, Result_Resurrect(owner, 'Faint', true, nil, true));
	table.insert(actions, Result_AddBuff(owner, owner, buff.AddBuff, 1, nil, true));
	table.insert(actions, Result_PropertyUpdated('IsHeadDisplay', false, owner, false));
	table.insert(actions, Result_PropertyUpdated('IsTurnDisplay', false, owner, false));
	table.insert(actions, Result_PropertyUpdated('Obstacle', true, owner, false));
	table.insert(actions, Result_PropertyUpdated('NoTurn', true, owner, false));
	table.insert(actions, Result_TurnEnd(owner));
	table.insert(actions, hpUpdate);
	local interaction = Result_UpdateInteraction(owner, 'CleanSite', true);
	interaction.sequential = true;
	table.insert(actions, interaction);
	SetInstantProperty(eventArg.Unit, 'RewardWhenResurrect', true);
	return unpack(actions);
end
----------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 유닛 피해 입을때 [UnitTakeDamage]
----------------------------------------------------------------------------
function Buff_DetectingWatchtower_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	if buff.DuplicateApplyChecker > 0
		or eventArg.Receiver ~= owner 
		or eventArg.Damage < 0
		or GetRelation(owner, eventArg.Giver) ~= 'Enemy' then
		return;
	end
	
	buff.DuplicateApplyChecker = 1;
	return Buff_Patrol_FindEnemy(owner, eventArg.Giver, nil, ds, false, nil, true, 'Patrol');
end
function Buff_IceSkin_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.name, 1);	
	return unpack(actions);
end
function Buff_StarShield_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner then
		return;
	end
	-- 버프 피해 시의 연출
	if eventArg.DamageBase > 0 and eventArg.DamageInfo.damage_type ~= 'Ability' then
		ds:Connect(ds:UpdateBattleEvent(GetObjKey(owner), 'StarShieldActivated', {Buff = buff.name}), eventArg.ActionID, 1);
	end
	if buff.DuplicateApplyChecker > 0 then
		return Result_RemoveBuff(owner, buff.name, true);
	end	
end
function Buff_StarBless_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 then
		return;
	end
	if owner.HP / owner.MaxHP > buff.ApplyAmount/100 then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	return unpack(actions);
end
function Buff_StarTrace_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 then
		return;
	end
	if owner.HP / owner.MaxHP > buff.ApplyAmount/100 then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner,  buff.AddBuff, 1, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	return unpack(actions);
end
function Buff_Rescue_TakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Damage < 0 then
		return;
	end
	-- 죽은 자는 말이 없다.
	if IsDead(owner) then
		return;
	end
	local actions = {};
	local buffType = nil;
	local additionalCommand = nil;
	if eventArg.Damage > 0 then
		if (GetTeam(eventArg.Giver) == 'player' and eventArg.Giver ~= owner) or GetBuff(owner, 'DistrustRescue') then
			table.insert(actions, Result_RemoveBuff(owner, buff.name));
			buffType = 'InjuredRageRescue';
			local modifier = nil;
			local distrustRescue = GetBuff(owner, 'DistrustRescue');
			if distrustRescue then
				modifier = function (buff)
					buff.DuplicateApplyChecker = distrustRescue.DuplicateApplyChecker;
				end;
			else
				additionalCommand = ds:ShowFrontmessageWithText(GuideMessageText('CivilDistrustPlayer'));
			end
			table.insert(actions, Result_AddBuff(owner, owner, 'InjuredRageRescue', 1, nil, modifier));
		elseif not GetBuff(owner, 'InjuredRescue') then
			table.insert(actions, Result_RemoveBuff(owner, buff.name));
			table.insert(actions, Result_AddBuff(owner, owner, 'InjuredRescue', 1));
			buffType = 'InjuredRescue';
		else
			return;
		end
	elseif buff.name == 'Rescue' and buff.name ~= 'Civil_Confusion' then
		table.insert(actions, Result_RemoveBuff(owner, buff.name));
		table.insert(actions, Result_AddBuff(owner, owner, 'Civil_Confusion', 1, nil, true));
		buffType = 'Civil_Confusion';
	else
		return;
	end
	
	local buffCls = GetClassList('Buff')[buffType];
	local camId = ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	ds:Connect(ds:PlayUIEffect(GetObjKey(owner), '_TOP_', 'GeneralNotifier', 0, 0, PackTableToString({Icon = buffCls.SubImage, Text = ClassDataText('Buff', buffType, 'Title'), FontColor = 'BrightRed', AnimationKey = 'TimeDown'})), camId, -1);
	if additionalCommand then
		ds:Connect(additionalCommand, camId, -1);
	end
	return unpack(actions);
end
function Buff_InjuredRescue_TakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Damage >= 0 then
		return;
	end
	-- 죽은 자는 말이 없다.
	if IsDead(owner) then
		return;
	end
	local user = eventArg.Giver;
	local target = owner;
	ds:Resurrect(GetObjKey(target));
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = 'InjuredRescue_'..objKey;
	UnregisterConnectionRestoreRoutine(mid, routinekey);
	
	SetInstantProperty(owner, 'InjuredRescue', nil);
	
	if GetInstantProperty(owner, 'CitizenType') == 'Unrest' then
		local actions = {};
		local debuffList = GetBuffType(owner, 'Debuff', 'Physical');
		for index, debuff in ipairs(debuffList) do
			table.insert(actions, Result_RemoveBuff(owner, debuff.name, true));
		end
		table.insert(actions, Result_RemoveBuff(owner, buff.name));
		InsertBuffActions(actions, owner, owner, 'Civil_Unrest', 1);		
		return unpack(actions);
	end
	
	-- 바로 구출
	AddUnitStats(user, 'Rescue', 1, true);
	return RescueHealthCitizen(target, user, ds, 'InjuredRescue', 'InjuredRescued');
end
function Buff_InjuredRageRescue_TakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Damage >= 0 then
		if GetTeam(eventArg.Giver) == 'player' then
			buff.DuplicateApplyChecker = 0;
		end
		return;
	end
	-- 죽은 자는 말이 없다.
	if IsDead(owner) then
		return;
	end
	local user = eventArg.Giver;
	local target = owner;
	-- 일으켜 세우자
	ds:Resurrect(GetObjKey(target));
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.name, -buff.Lv);
	InsertBuffActions(actions, owner, owner, 'DistrustRescue', 1, nil, function(b)
		b.DuplicateApplyChecker = buff.DuplicateApplyChecker;
	end);
	
	ds:Resurrect(GetObjKey(target));
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = 'InjuredRescue_'..objKey;
	UnregisterConnectionRestoreRoutine(mid, routinekey);
	
	SetInstantProperty(owner, 'InjuredRescue', nil);
	return unpack(actions);
end
function Buff_Ice_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner
		or buff.Disabled 
		or eventArg.Damage <= 0
		or eventArg.DamageInfo.damage_sub_type ~= 'Ice' then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	return unpack(actions);
end
function Buff_Taming_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'TamingTarget');
	if GetObjKey(eventArg.Receiver) ~= targetKey
		or eventArg.Damage <= 0 then
		return;
	end
	local target = nil;
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	return Result_FireWorldEvent('TamingFailed', {Unit=owner, Target=target});
end
function Buff_Communicating_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'CommunicatingTarget');
	if GetObjKey(eventArg.Receiver) ~= targetKey
		or eventArg.Damage <= 0 then
		return;
	end
	local target = nil;
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	return Result_FireWorldEvent('CommunicatingFailed', {Unit=owner, Target=target});
end
function Buff_Occupying_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Damage <= 0 then
		return;
	end
	return Result_FireWorldEvent('OccupyingFailed', {Unit=owner}, owner);
end
function Buff_BeastLoyaltyCommon_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	local masterKey = GetInstantProperty(owner, 'SummonMaster');
	if GetObjKey(eventArg.Receiver) ~= masterKey
		or GetObjKey(eventArg.Giver) == masterKey
		or eventArg.Damage <= 0 then
		return;
	end
	local actions = {};
	local targetKey = GetObjKey(eventArg.Giver);
	local targetSet = GetInstantProperty(owner, 'BeastRoyaltyTarget') or {};
	targetSet[targetKey] = true;
	table.insert(actions, Result_UpdateInstantProperty(owner, 'BeastRoyaltyTarget', targetSet));
	return unpack(actions);
end
-- 반항적
function Buff_BeastLoyaltyBad_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Damage <= 0 then
		return;
	end
	local buff_Arbitrary = GetBuff(owner, buff.AddBuff);
	local escapeProb = buff_Arbitrary and math.floor(buff_Arbitrary.Lv / buff.ApplyAmount) * buff.ApplyAmount2 or 0;
	if not RandomTest(escapeProb) then
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
	local actions = {};
	ds:Move(GetObjKey(owner), pos, false, false);
	ApplyUnsummonBeastActions(actions, giver, owner);
	return unpack(actions);
end
-- 얼음 갑옷
function Buff_IceArmor_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 then
		return;
	end
	-- 셀프 데미지는 무시
	if eventArg.Giver == owner then
		return;
	end	
	local actions = {};
	local target = eventArg.Giver;
	InsertBuffActions(actions, owner, target, buff.AddBuff, 1, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	return unpack(actions);
end
-- 맹독 갑옷
function Buff_PoisonArmor_UnitTakeDamage(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 then
		return;
	end
	-- 셀프 데미지는 무시
	if eventArg.Giver == owner then
		return;
	end	
	local actions = {};
	local target = eventArg.Giver;
	InsertBuffActions(actions, owner, target, buff.AddBuff, 1, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 버프 추가 [BuffAdded]
----------------------------------------------------------------------------
-- 흉폭한 멍고, 포효하는 멍고
---@param eventArg buffAddedEventArg
---@param buff class_Buff
---@param owner unit
---@param giver unit
---@param ds DirectingScripter
function Buff_Munggo_RageMode_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff.Type ~= 'Debuff' 
		or eventArg.Buff.SubType ~= 'Mental' then
		return;
	end

	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', {Buff = buff.name});
	return unpack(actions);
end
-- 유쾌한 멍고, 환호하는 멍고
---@param eventArg buffAddedEventArg
---@param buff class_Buff
---@param owner unit
---@param giver unit
---@param ds DirectingScripter
function Buff_Munggo_HappyMode_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff.Type ~= 'Buff' 
		or eventArg.Buff.SubType ~= 'Mental' then
		return;
	end

	local actions = {};
	AddActionApplyActForDS(actions, owner, owner, -buff.ApplyAmount, ds, 'Friendly');
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', {Buff = buff.name});
	return unpack(actions);
end
-- 연막 생성기
function Buff_Generator_Smoke_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	
	return Buff_Generator_Smoke_Activate(owner, GetPosition(owner));
end
function Buff_Generator_Smoke_Activate(owner, pos)
	local mission = GetMission(owner);
	local fieldEffect = GetClassList('FieldEffect').SmokeScreen;
	local range = Linq.new(CalculateRange(owner, 'Box1', pos))
		:where(function(pos) return fieldEffect:IsEffectivePosition(pos, mission); end)
		:toList();
	return Result_AddFieldEffect(fieldEffect.name, range, owner);
end
-- 제어권 탈취
function Buff_ControlTakeover_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	local actions = {};
	if giver then
		local ctots = GetInstantProperty(giver, 'ControlTakingOverTargets') or {};
		table.insert(ctots, GetObjKey(owner));
		table.insert(actions, Result_UpdateInstantProperty(giver, 'ControlTakingOverTargets', ctots));
	end
	table.insert(actions, Result_FireWorldEvent('FriendlyMachineHasJoined', {Machine = owner, FirstJoin = true}, nil, true));
	table.insert(actions, Result_GiveAbility(owner, 'ControlGiveBack'));
	if giver then
		-- 재기동 최적화 알고리즘
		local mastery_RestartOptimaztionAlgorithm = GetMasteryMastered(GetMastery(giver), 'RestartOptimaztionAlgorithm');
		if mastery_RestartOptimaztionAlgorithm then
			MasteryActivatedHelper(ds, mastery_RestartOptimaztionAlgorithm, owner, 'BuffAdded');
			table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
			if not owner.TurnState.TurnEnded then
				table.append(actions, {GetInitializeTurnActions(owner)});
			end
		end
		local masterKey = GetInstantProperty(owner, 'SummonMaster');
		if masterKey == GetObjKey(giver) then
			-- 원 소유자로 되돌아갔으면 바로 해제 (뭔가 이상하지만 '재기동 최적화 알고리즘'가 적용되긴 해야될테니...)
			table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
		end
	end
	return unpack(actions);
end
-- 먹이를 낚음
function Buff_HavingPrey_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	local actions = {};
	table.insert(actions, Result_PropertyUpdated('TurnState/SpecialChecker', 'CheckUsableByTurnState_HavingPrey', owner, false));
	return unpack(actions);
end
-- 마음의 눈 사용중
function Buff_UsingBeholderVision2_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	local actions = {};
	table.insert(actions, Result_PropertyUpdated('TurnState/SpecialChecker', 'CheckUsableByTurnState_UsingBeholderVision2', owner, false));
	local refTarget = GetUnit(GetMission(owner), buff.ReferenceTarget);
	if refTarget then
		table.insert(actions, Result_UpdateInstantProperty(owner, 'FocusObjectKey', GetObjKey(refTarget)));	
	end	
	return unpack(actions);
end
-- 석화
function Buff_Petrifaction_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	local actions = {};
	-- 버프 제거
	local removeBuffList = GetBuffType(owner, 'Buff');
	local removeDebuffList = GetBuffType(owner, 'Debuff');
	-- 버프 해제 면역
	local immuneMastery = GetMasteryMasteredImmuneRemoveBuff(GetMastery(owner));
	if immuneMastery and #removeBuffList > 0 then
		MasteryActivatedHelper(ds, immuneMastery, owner, 'ImmuneRemoveBuff');
		removeBuffList = {};
	end
	for _, buffList in ipairs({ removeBuffList, removeDebuffList }) do
		for _, buff in ipairs(buffList) do
			InsertBuffActions(actions, owner, owner, buff.name, -buff.Lv);
			ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
		end
	end
	-- 엄폐 추가
	table.insert(actions, Result_ChangeCoverInfo(owner, 'SimpleBlockOne'));
	-- 매터리얼 변경
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = buff.name..'ChangeMaterial'..objKey;
	RegisterConnectionRestoreRoutine(mid, routinekey, function(ds)
		ds:ChangeMaterial(objKey, '_Stone', true);
	end);
	ds:ChangeMaterial(objKey, '_Stone', true);
	return unpack(actions);
end
-- 불안정한 혼합물
function Buff_UnstableConcoction_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	
	-- 한번에 10랩짜리가 들어오면 터짐
	if eventArg.BuffLevel >= buff:MaxStack(owner) then
		return Result_FireWorldEvent('ConcoctionFlooded', {}, owner, true);
	end
end
function Buff_TargetChecking_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	
	local refTarget = GetUnit(GetMission(owner), buff.ReferenceTarget);
	AddHate(owner, refTarget, 9999);
	local actions = {};
	InsertBuffActionsMultiGiver(actions, owner, refTarget, 'Aimed', true, true, nil, true);
	return unpack(actions);
end
function Buff_Provocation_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	SetInstantProperty(owner, 'AggroTarget', giver);
end

function Buff_ConcealForAura_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	if not HasBuff(owner, 'Conceal') then
		return;
	end
	return Result_RemoveBuff(owner, 'Conceal');
end

function Buff_IronWall_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end

	return Result_ChangeCoverInfo(owner, 'SimpleBlockOne');
end
function GetNotCoveredPosition(owner, distance, notAllowed, giver)
	if not IsCoveredPosition(GetMission(owner), GetPosition(owner)) then
		-- 엄폐되지 않는 위치에서는 안함
		return;
	end
	
	-- 약간의 높이 차에 대응하기 위한 수치 보정
 	local distance = distance + 0.4;

	local pos, score, _ = FindAIMovePosition(owner, {FindMoveAbility(owner)}, function (self, adb)
		if adb.MoveDistance > distance then
			return -100;	-- 거리제한
		end
		if PositionInRange(notAllowed, adb.Position) then
			return -100;
		end
		
		if not adb.Coverable then
			return 1000;
		end
		if giver then
			return math.min(adb.BaseMoveDistanceTo(giver), 99);
		else
			return math.random(1, 99);
		end
	end, {}, {});

	if score <= 0 then
		return;
	end
	
	return pos;
end

function IsEnableAstonishment(owner)
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return false;
	end
	if not IsCoveredObject(owner) or not owner.Coverable or not owner.Movable then
		return false;
	end
	return true;
end
function Buff_Astonishment_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	if not IsEnableAstonishment(owner) then
		return Result_RemoveBuff(owner, buff.name, true);
	end
	return Result_DirectingScript(function(mid, ds, args)
		if not IsEnableAstonishment(owner) then
			return Result_RemoveBuff(owner, buff.name, true);
		end
		local moveDistance = 4;
		local instantSession = GetMissionInstantSession(mid);
		local movePos = GetNotCoveredPosition(owner, moveDistance, instantSession.ReservedPositions, giver);
		if movePos then
			ForceNewInsert(instantSession, 'ReservedPositions', movePos);
			local ownerKey = GetObjKey(owner);
			local id = ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
			local moveId = ds:Move(ownerKey, movePos, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, {Type = 'Buff', Value = buff.name, Unit = giver});
			ds:Connect(moveId, id, -1);
			ds:SetCommandLayer(id, game.DirectingCommand.CM_SECONDARY);
			ds:SetContinueOnNormalEmpty(id);
		end	
		return Result_RemoveBuff(owner, buff.name, true), Result_TurnEnd(owner);
	end, nil, true, true);
end

function Buff_Stabilized_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local unitKey = GetObjKey(owner);
	ds:UpdateBalloonCivilMessage(unitKey, 'Rescued', owner.Info.AgeType);
	local actions = {};
	table.insert(actions, Result_PropertyUpdated('IsTurnDisplay', true, owner));
	return unpack(actions);
end
function Buff_Blind_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local particleID = ds:PlayParticle(GetObjKey(owner), '_TOP_', 'Particles/Dandylion/Buff_Blind_Start', 2);
	ds:SetCommandLayer(particleID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(particleID);
	-- 오버워치 버프 지우기.
	local actions = {};
	if HasBuff(owner, 'Overwatching') then
		table.insert(actions, Result_RemoveBuff(owner, 'Overwatching', true));
		if not eventArg.AbilityBuff then
			local visible = ds:EnableIf('TestObjectVisibleAndAlive', GetObjKey(owner));
			local buffDischargedID = ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = 'Overwatching' });
			ds:Connect(buffDischargedID, visible, -1);
			ds:SetCommandLayer(buffDischargedID, game.DirectingCommand.CM_SECONDARY);
			ds:SetContinueOnNormalEmpty(visible);
		end
	end
	return unpack(actions);
end
function Buff_Blind_AbilityBuffInvoked(buffCls, owner)
	if HasBuff(owner, 'Overwatching') then
		AddBattleEvent(owner, 'BuffDischargedFromAbility', { Buff = 'Overwatching', EventType = buffCls.AbilityBuffEvent });
	end
end
function Buff_Blackout_Message_BuffAdded(eventArg, buff, owner, giver, ds)
	if IsPlayerTeam(eventArg.Unit) then
		return;
	end
	
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	
	local unitKey = GetObjKey(owner);
	if RandomTest(50) then
		ds:UpdateBalloonCivilMessage(unitKey, 'Blackout', owner.Info.AgeType, nil, 0);
	end
end
function Buff_Blackout_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or not IsBuffType(eventArg.Buff, 'Debuff', nil, 'Light') then
		return;
	end
	return Buff_Blackout_InvokeCommon(owner, GetBuffGiver(eventArg.Buff), ds);
end
function Buff_Blackout_FlareOccured(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	return Buff_Blackout_InvokeCommon(owner, eventArg.Trigger, ds);
end
function Buff_Blackout_InvokeCommon(owner, trigger, ds)
	local eventCls = GetClassList('ChainEvent')['BlackoutFlashed'];
	if not eventCls then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, eventCls.ApplyBuff.name, 1, true);
	local playId = ds:PlayUIEffect(GetObjKey(owner), '', 'BigText', 0, 0, PackTableToString({Text = ClassDataText('ChainEvent', eventCls.name, 'Title'), Font = eventCls.Font, AnimKey = eventCls.AnimKey, Color = eventCls.Color}));
	ds:SetCommandLayer(playId, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(playId);
	table.insert(actions, Result_FireWorldEvent('ChainEffectOccured', {Unit=owner, Trigger = trigger, ChainType = eventCls.name}, nil, true));
	return unpack(actions);
end
function Buff_Civil_Confusion_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
end
function Buff_Unrest_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	return Result_UpdateInteraction(owner, 'Comfort', true);
end
function Buff_InjuredRescue_Initialize_Common(owner, ds, direct)
	if GetInstantProperty(owner, 'InjuredRescue') then
		return;
	end
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = 'InjuredRescue_'..objKey;
	RegisterConnectionRestoreRoutine(mid, routinekey, function(ds)
		local deadID = ds:SetDead(objKey, 'Normal', 0, 0, 0, 0, 0, true, true);
		ds:SetCommandLayer(deadID, game.DirectingCommand.CM_SECONDARY);
		ds:SetContinueOnNormalEmpty(deadID);
	end);
	local deadID = ds:SetDead(objKey, 'Normal', 0, 0, 0, 0, 0, direct, true);
	if direct then
		ds:SetCommandLayer(deadID, game.DirectingCommand.CM_SECONDARY);
		ds:SetContinueOnNormalEmpty(deadID);
	end
	SetInstantProperty(owner, 'InjuredRescue', true);
	return Result_UpdateInteraction(owner, 'Cure', true);
end
function Buff_InjuredRescue_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	return Buff_InjuredRescue_Initialize_Common(owner, ds, false);
end
function Buff_InjuredRescue_MissionPrepare(eventArg, buff, owner, giver, ds)
	return Buff_InjuredRescue_Initialize_Common(owner, ds, true);
end
function Buff_InjuredRescue_UnitPositionChanged(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	return Buff_InjuredRescue_Initialize_Common(owner, ds, true);
end
function Buff_Confusion_BuffAddedSelf(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local playId = ds:UpdateBalloonCivilMessage(GetObjKey(owner), 'Confused', owner.Info.AgeType, 'Shout_Enemy');
	ds:SetCommandLayer(playId, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(playId);
	
	return Result_FireWorldEvent('BuffAddedAction', {Unit=owner, BuffName=buff.name}, owner, true);
end
function Buff_Confusion_BuffAddedAction(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.BuffName ~= buff.name then
		return;
	end
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	-- 혼란으로 이동 시 문제가 발생하므로, 순찰 버프 제거
	for i, action in ipairs(GetRemovePreBattleStateBuffActions(owner)) do
		ds:WorldAction(action, false);
	end
	local start = os.clock();
	local abilities = GetAvailableAbility(owner, true);
	local moveAbility = FindMoveAbilityInList(abilities);	
	if moveAbility then
		-- 근접계열 : 가장 가까운 적 옆으로
		-- 원거리계열 : 가장 가까운 엄폐 장소로
		local moveStrategy = nil;
		if owner.Job.AttackType == 'Melee' then
			moveStrategy = function(self, adb, args)
				return 1000 - adb.MinEnemyDistance + math.random();
			end;
		else
			moveStrategy = function(self, adb, args)
				if not adb.Coverable then
					return -1;
				end
				return math.random(1, 100);
			end
		end
		
		local movePos = nil;
		local prevPos = GetPosition(owner);
		local pos, score = FindAIMovePosition(owner, abilities, moveStrategy, {NoneBlock=true}, {});
		if score ~= nil and score >= 0 and not IsSamePosition(pos, prevPos) then
			movePos = pos;
		end
		if movePos then
			local moveAction = Result_UseAbility(owner, moveAbility.name, movePos, {}, true, {NoCamera = true});
			ds:WorldAction(moveAction, true);
		end
	end

	local startID = ds:Sleep(0);
	ds:SetCommandLayer(startID, game.DirectingCommand.CM_SECONDARY);
	local prevID = startID;

	-- 공격 어빌리티 사용
	local usingAbility, usingPos, _, score = FindAIMainAction(owner, abilities, {{Strategy = NearFirstAttackAI, Target = 'Attack'}}, {SelfSightOnly = true, NoIndirect = true}, {});
	if usingAbility and score >= 0 then
		local attackAction = Result_UseAbility(owner, usingAbility.name, usingPos, {}, true, {NoCamera = true});
		attackAction.final_useable_checker = function()
			return GetBuffStatus(owner, 'Attackable', 'And')
				and PositionInRange(CalculateRange(owner, usingAbility.TargetRange, GetPosition(owner)), usingPos);
		end;
		local attackID = ds:WorldAction(attackAction, true);
		if attackID ~= -1 then
			ds:Connect(attackID, prevID, -1);
			prevID = attackID;
		end
	end

	-- 턴 종료
	if not IsDead(owner) then
		local turnEndAction = Result_TurnEnd(owner);
		local turnEndID = ds:WorldAction(turnEndAction, true);
		ds:Connect(turnEndID, prevID, -1);
	end
	LogAndPrint('Confusion Added elapsed:', os.clock() - start);
end
function Buff_BuffAdded_DischargeOnUnconscious(eventArg, buff, owner, giver, ds)
	if not eventArg.Buff.Unconscious then
		return;
	end
	return Result_RemoveBuff(owner, buff.name);
end
function Buff_ClimbWeb_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	
	local mission = GetMission(owner);
	local newObjKey = GenerateUnnamedObjKey(mission);
	local createAction = Result_CreateObject(newObjKey, 'Utility_ClimbWebTrace', GetPosition(owner), '_neutral_', function(obj, arg)
		UNIT_INITIALIZER_NON_BATTLE(obj, obj.Team);
	end, nil, 'DoNothingAI', {}, true);
	createAction.sequential = true;
	ds:WorldAction(createAction);
	
	local prevProps = {};
	prevProps.NotOccupy = owner.NotOccupy;
	prevProps.DummyObjKey = newObjKey;
	SetInstantProperty(owner, 'ClimbWeb', prevProps);

	local actions = {};
	table.insert(actions, Result_PropertyUpdated('NotOccupy', true, owner));
	
	local dummyObj = GetUnit(mission, newObjKey);
	if dummyObj then
		table.insert(actions, Result_AddBuff(dummyObj, dummyObj, 'ClimbWebEffect', 1, nil, true));
	end
	
	return unpack(actions);
end
function Buff_BeingFished_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	
	local mission = GetMission(owner);
	local newObjKey = GenerateUnnamedObjKey(mission);
	local createAction = Result_CreateObject(newObjKey, 'Utility_ClimbWebTrace', GetPosition(owner), '_neutral_', function(obj, arg)
		UNIT_INITIALIZER_NON_BATTLE(obj, obj.Team);
	end, nil, 'DoNothingAI', {}, true);
	createAction.sequential = true;
	ds:WorldAction(createAction);
	
	local prevProps = {};
	prevProps.NotOccupy = owner.NotOccupy;
	prevProps.DummyObjKey = newObjKey;
	SetInstantProperty(owner, 'BeingFished', prevProps);

	local actions = {};
	table.insert(actions, Result_PropertyUpdated('NotOccupy', true, owner));
	
	local dummyObj = GetUnit(mission, newObjKey);
	if dummyObj then
		table.insert(actions, Result_AddBuff(dummyObj, dummyObj, 'ClimbWebEffect', 1, nil, true));
	end
	
	return unpack(actions);
end
function Buff_Burrow_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff
		and eventArg.Buff.name ~= 'ExposurePosition' then
		return;
	end
	local actions = {};
	if eventArg.Buff == buff then
		local mission = GetMission(owner);
		local newObjKey = GenerateUnnamedObjKey(mission);
		local createAction = Result_CreateObject(newObjKey, 'Utility_BurrowTrace', GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER_NON_BATTLE(obj, obj.Team);
		end, nil, 'DoNothingAI', {}, true);
		createAction.sequential = true;
		ds:WorldAction(createAction);
		
		local prevProps = {};
		prevProps.NotOccupy = owner.NotOccupy;
		prevProps.DummyObjKey = newObjKey;
		SetInstantProperty(owner, 'Burrow', prevProps);

		table.insert(actions, Result_PropertyUpdated('NotOccupy', true, owner));
		
		local dummyObj = GetUnit(mission, newObjKey);
		if dummyObj then
			table.insert(actions, Result_AddBuff(dummyObj, dummyObj, 'BurrowEffect', 1, nil, true));
		end
		-- 재접속 시의 숨김 처리
		local mid = GetMissionID(owner);
		local objKey = GetObjKey(owner);
		local routineKey = buff.name..'Hide'..objKey;
		RegisterConnectionRestoreRoutine(mid, routineKey, function(ds)
			ds:HideObject(objKey);
		end);
	else
		-- 위치 노출로 인한 버로우 해제
		if buff.Life > 0 then
			-- 땅꿀 숨기 해제 처리
			local subActions = { Buff_Burrow_InvokeDisableDigging(buff, owner, ds, true) };
			table.append(actions, subActions);
		end
		table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	end
	return unpack(actions);
end
function Buff_Flow_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	local mid = GetMissionID(owner);
	local particleKey = 'FlowAlertArea_'..GetObjKey(owner);
	local watchingArea = GetInstantProperty(owner, 'FlowWatchingArea');
	RegisterConnectionRestoreRoutine(mid, particleKey, function(ds)
		ds:MissionVisualArea_AddCustomMulti(particleKey, watchingArea, 'Particles/Dandylion/Buff_FlowMark', true);
	end);
	ds:MissionVisualArea_AddCustomMulti(particleKey, watchingArea, 'Particles/Dandylion/Buff_FlowMark', true);
end
function Buff_ObjectFreezer_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = buff.name..'ObjectFreezer'..objKey;
	RegisterConnectionRestoreRoutine(mid, routinekey, function(ds)
		local poseID = ds:PlayPose(objKey, owner.StandingAnimation, '', false);
		ds:SetCommandLayer(poseID, game.DirectingCommand.CM_SECONDARY);
		ds:SetContinueOnNormalEmpty(poseID);
	end);
	local poseID = ds:PlayPose(objKey, owner.StandingAnimation, '', false);
	ds:SetCommandLayer(poseID, game.DirectingCommand.CM_SECONDARY);
end
function Buff_Taming_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		if eventArg.Buff.Unconscious or eventArg.Buff.Untargetable then
			local targetKey = GetInstantProperty(owner, 'TamingTarget');
			local target = nil;
			if targetKey then
				local mission = GetMission(owner);
				target = GetUnit(mission, targetKey);
			end
			if target then
				return Result_FireWorldEvent('TamingFailed', {Unit=owner, Target=target});
			end
		end
		return;
	end
	RaiseHateCustom(owner, 'Taming', 100);
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = 'Taming_'..objKey;
	RegisterConnectionRestoreRoutine(mid, routinekey, function(ds)
		ds:LookAt(objKey, GetInstantProperty(owner, 'TamingTarget'), true);
		ds:PlayPose(objKey, 'TameStart', 'TameStd', false, 'TameStdIdle', true);
	end);
end
function Buff_Communicating_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		if eventArg.Buff.Unconscious or eventArg.Buff.Untargetable then
			local targetKey = GetInstantProperty(owner, 'InteractionTarget');
			local target = nil;
			if targetKey then
				local mission = GetMission(owner);
				target = GetUnit(mission, targetKey);
			end
			if target then
				return Result_FireWorldEvent('CommunicatingFailed', {Unit=owner, Target=target}, owner, true);
			end
		end
		return;
	end
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = 'Occupying_'..objKey;
	RegisterConnectionRestoreRoutine(mid, routinekey, function(ds)
		ds:LookAt(objKey, GetInstantProperty(owner, 'InteractionTarget'), true);
		ds:PlayPose(objKey, 'InteractionStart', 'InteractionStd', false, 'InteractionStdIdle', true);
	end);
end
function Buff_Occupying_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		if eventArg.Buff.Unconscious or eventArg.Buff.Untargetable then
			local targetKey = GetInstantProperty(owner, 'InteractionTarget');
			local target = nil;
			if targetKey then
				local mission = GetMission(owner);
				target = GetUnit(mission, targetKey);
			end
			if target then
				return Result_FireWorldEvent('OccupyingFailed', {Unit=owner, Target=target});
			end
		end
		return;
	end
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = 'Occupying_'..objKey;
	RegisterConnectionRestoreRoutine(mid, routinekey, function(ds)
		ds:LookAt(objKey, GetInstantProperty(owner, 'InteractionTarget'), true);
		ds:PlayPose(objKey, 'InteractionStart', 'InteractionStd', false, 'InteractionStdIdle', true);
	end);
end
function Buff_Flare_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local lightBuff = GetClassList('Buff')['Blind'];

	local targetArgs = {};
	local targetRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
	local targetObjects = BuffHelper.GetObjectsInRange(GetMission(owner), targetRange);
	
	local actions = {};
	for _, obj in pairs(targetObjects) do
		if not BuffImmunityTest(lightBuff, obj) then
			table.insert(actions, Result_FireWorldEvent('FlareOccured', {Unit = obj, Trigger = giver}, obj, true));
		end
	end
	return unpack(actions);	
end
-- 은신
function Buff_Stealth_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Buff == buff then
		local mission = GetMission(owner);
		---@type AISession
		for _, aiSession in pairs(GetAllAISession(mission)) do
			aiSession:RemoveTemporalSightObject(owner);
		end
		SetInstantProperty(owner, 'StealthDetected', nil);
		-- 어빌리티 연출로 HideObject를 했을 가능성이 있으므로, 이후 발각 시를 위해 ShowObject를 해줌
		ds:ShowObject(GetObjKey(owner));
	end
	if eventArg.Buff.Detected or (eventArg.Buff == buff and owner.Detected) then
		return Result_RemoveBuff(owner, buff.name, true), Result_DirectingScript(function(mid, ds, args)
			ds:Sleep(0.05);
			ds:PlayParticle(GetObjKey(owner), '_CENTER_', 'Particles/Dandylion/UnleashedCamouflage', 2, false, false, true);
			ds:Sleep(0.5);
			ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
			ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
			ds:Sleep(0.05);
		end, nil, true);
	end
end
-- 자애의 선물
function Buff_GiftOfLove_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local actions = {};
	local hpAmount = math.floor(owner.MaxHP * buff.ApplyAmount / 100);

	local sleep = ds:Sleep(0);
	ds:SetCommandLayer(sleep, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(sleep);

	AddActionRestoreHPForDS(actions, owner, owner, hpAmount, ds, 'GiftOfLove', sleep, -1);
	return unpack(actions);
end
-- 각인
function Buff_Imprinting_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	-- 사냥꾼 AI의 야수 소환 시의 야수 AI를 재탕함
	SetMonsterAIInfo(owner, 'BeastAI', {AlwaysApplyRallyPoint = true,
		RallyPoint = {{Type = 'Object', ObjectKey = GetObjKey(giver)}},
		RallyPower = 30,
		RallyRange = 4,
		HateRatio = 5,
	});
	return Result_UpdateInstantProperty(owner, 'SummonMaster', GetObjKey(giver));
end
-- 주시
function Buff_BeholderVision_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	return Result_SightSharing(owner, GetTeam(giver), true, true);
end
-- 눈속임 - 적대
function Buff_NegativeTrickery_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local pos = GetPosition(owner);
	ds:Move(GetObjKey(owner), pos);
end
-- 눈속임 - 변이
function Buff_ChangeTrickery_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local actions = {};
	local originalShape = GetInstantProperty(owner, buff.name);
	if not originalShape then
		table.insert(actions, Result_UpdateInstantProperty(owner, buff.name, owner.Shape.name));
	end
	local shapeName = 'Object_PePe';
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	-- 연출용
	if not eventArg.AbilityBuff then
		local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/powder_green', 1, false, false, true);
		local changeShapeID = ds:ChangeShape(objKey, shapeName, false);
		ds:SetCommandLayer(particleID, game.DirectingCommand.CM_SECONDARY);
		ds:SetContinueOnNormalEmpty(particleID);
		ds:Connect(changeShapeID, particleID, 0.1);
	end
	-- 복원용
	local routineKey = 'ChangeTrickery'..objKey;
	RegisterConnectionRestoreRoutine(mid, routineKey, function(ds)
		local changeShapeID = ds:ChangeShape(objKey, shapeName, false);
		ds:SetCommandLayer(changeShapeID, game.DirectingCommand.CM_SECONDARY);
		ds:SetContinueOnNormalEmpty(changeShapeID);
	end);
	return unpack(actions);
end
-- 바람 사슬
function Buff_WindChain_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	-- '바람 사슬' 어빌리티에 걸리는 버프와 '구속력' 특성으로 걸리는 버프가 동시에 걸리면 안 됨
	local removeBuff = 'WindChain';
	if buff.name == 'WindChain' then
		removeBuff = 'WindChain_For_Ability';
	end
	if not HasBuff(owner, removeBuff) then
		return;
	end
	return Result_RemoveBuff(owner, removeBuff);
end
-- 물 감옥
function Buff_WaterJail_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	-- '바람 사슬'과 다르게 해당 버프를 걸어주는 특성이 없으나, 추후 어떻게 될 지 모르니 일단 구조를 동일하게 맞춰둠
	local removeBuff = 'WaterJail';
	if buff.name == 'WaterJail' then
		removeBuff = 'WaterJail_For_Ability';
	end
	return Result_RemoveBuff(owner, removeBuff);
end
-- 육도윤회
function Buff_SixPathSamsara_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local actions = {};
	local abilityList = GetAllAbility(owner, false, true);
	for index, ability in ipairs(abilityList) do
		if ability.Category == 'Ninjutsu' and ability.name ~= 'SixPathSamsara' and ability.IsUseCount and ability.UseCount < ability.MaxUseCount then
			UpdateAbilityPropertyActions(actions, owner, ability.name, 'UseCount', ability.MaxUseCount);
		end
	end
	return unpack(actions);
end
-- 승격
function Buff_Promotion_BuffAdded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local actions = {};
	local addLv = buff.ApplyAmount;
	table.insert(actions, Result_PropertyAdded('Lv', addLv, owner));
	table.insert(actions, Result_PropertyAdded('PromotionLv', addLv, owner));
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 버프 제거 [BuffRemoved]
----------------------------------------------------------------------------
function Buff_Exhaustion_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end

	local actions = {};
	AddActionOverloadForDS(actions, owner, -500, true, true, ds, true);
	return unpack(actions);
end
-- 사후 탈피
function Buff_MoltAfterDeath_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end

	local bb = RandomTest(95) and buff.AddBuff or buff.AddBuff2;

	local actions = {};
	ds:Resurrect(GetObjKey(owner));
	AddActionRestoreHPForDS(actions, owner, owner, owner.MaxHP, ds);
	if owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner, true)});
	end
	InsertBuffActions(actions, owner, owner, bb, 1, true);

	return unpack(actions);
end
-- 폭주(기계)
function Buff_MachineFury_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	local damage = owner.HP;
	local realDamage, reasons = ApplyDamageTest(owner, damage, 'SystemBuff');
	local isDead = owner.HP <= realDamage;
	local remainHP = math.clamp(owner.HP - realDamage, 0, owner.MaxHP);
	DirectDamageByType(ds, owner, 'MachineFury', damage, remainHP, true, isDead);
	return Result_Damage(damage, 'Normal', 'Hit', owner, owner, 'SystemBuff', 'Etc', buff);
end
-- 제어권 탈취
function Buff_ControlTakeover_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	local actions = {};
	if giver then
		local ctots = GetInstantProperty(giver, 'ControlTakingOverTargets') or {};
		ctots = table.filter(ctots, function(ctot) return ctot ~= GetObjKey(owner) end);
		table.insert(actions, Result_UpdateInstantProperty(giver, 'ControlTakingOverTargets', ctots));
	end
	table.insert(actions, Result_FireWorldEvent('FriendlyMachineAboutToLeave', {Machine = owner, MasterKey = giver and GetObjKey(giver) or nil}));
	return unpack(actions);
end
-- 먹이를 낚음
function Buff_HavingPrey_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	local actions = {};
	table.insert(actions, Result_PropertyUpdated('TurnState/SpecialChecker', 'None', owner, false));
	return unpack(actions);
end
-- 마음의 눈 사용중
function Buff_UsingBeholderVision2_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.BuffName ~= buff.name then
		return;
	end
	local actions = {};
	table.insert(actions, Result_PropertyUpdated('TurnState/SpecialChecker', 'None', owner, false));
	table.insert(actions, Result_UpdateInstantProperty(owner, 'FocusObjectKey', nil));
	return unpack(actions);
end
-- 별빛 감옥
function Buff_StarlightJail_BuffRemoved(eventArg, buff, owner, giver, ds)
	return Result_FireWorldEvent('InvalidateAuraTarget_Self', {Unit = owner}, owner), Result_FireWorldEvent('InvalidateAuraTarget', {Unit = owner});
end
function Buff_TargetChecking_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	
	local refTarget = GetUnit(GetMission(owner), buff.ReferenceTarget, true);
	AddHate(owner, refTarget, -9999);
	
	local actions = {};
	InsertBuffActionsMultiGiver(actions, owner, refTarget, 'Aimed', false, true, nil, true);
	return unpack(actions);
end
function Buff_Provocation_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	SetInstantProperty(owner, 'AggroTarget', nil);
end

function Buff_IronWall_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end

	local defaultCoverInfo = owner.OccupyType.CoverInfo.name;
	return Result_ChangeCoverInfo(owner, defaultCoverInfo);
end

function Buff_FortressOfIron_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or (eventArg.Buff.name ~= 'IronWall' and eventArg.Buff.name ~= 'FrostWall') then
		return;
	end

	return Result_RemoveBuff(owner, buff.name);
end

function Buff_MovingCastle_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff.name ~= 'MagicOuterArmor' then
		return;
	end

	return Result_RemoveBuff(owner, buff.name);
end
function Buff_Trick_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	local pos = GetPosition(owner);
	ds:Move(GetObjKey(owner), pos);
end
function Buff_Death_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner 
		or eventArg.Buff ~= buff
		or GetMasteryMastered(GetMastery(owner), 'Amulet_Scourge') then
		return;
	end
	if buff.Life > 0 then
		-- 해제 이펙트 띄워 주자.
		return;
	end
	local actions = {};
	local damage, reasons = ApplyDamageTest(owner, owner.MaxHP, 'Buff');
	local isDead = owner.HP <= damage;
	local isFocus = true;
	DirectDamageByType(ds, owner, buff.name, owner.MaxHP, owner.HP - damage, isFocus, isDead, nil, 0);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	AddBuffDamageChat(ds, owner, buff, damage);
	table.insert(actions, Result_Damage(owner.MaxHP, 'Normal', 'Hit', owner, owner, 'Buff', 'Etc', buff));
	return unpack(actions);
end
-- 조명탄
function Buff_Flare_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local actions = {};
	table.insert(actions, Result_ChangeTeam(owner, '_dummy', false));
	table.insert(actions, Result_DestroyObject(owner, false, true));
	return unpack(actions);
end
function Buff_Stabilized_BuffRemoved(eventArg, buff, owner, giver, ds)
	if buff ~= eventArg.Buff 
		or buff.Life > 0 then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, giver, owner, 'Civil_Unrest', 1);
	table.insert(actions, Result_PropertyUpdated('IsTurnDisplay', false, owner));
	ds:ShowFrontmessageWithText(GuideMessageText('CivilUnrest'), 'Corn');
	return unpack(actions);
end
function Buff_Charm_BuffRemoved(eventArg, buff, owner, giver, ds)
	if buff ~= eventArg.Buff then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:PlayAni(objKey, 'Rage', false);
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	return unpack(actions);
end
function Buff_Civil_Confusion_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	
	local actions = {};
	local citizenType = GetInstantProperty(owner, 'CitizenType');
	if citizenType == 'Healthy' then
		InsertBuffActions(actions, owner, owner, 'Rescue');
	elseif citizenType == 'Unrest' then
		InsertBuffActions(actions, owner, owner, 'Civil_Unrest');
	end
	return unpack(actions);
end
function Buff_Unrest_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	return Result_UpdateInteraction(owner, 'Comfort', false);
end
function Buff_InjuredRescue_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	return Result_UpdateInteraction(owner, 'Cure', false);
end
function Buff_ClimbWeb_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	
	local prevProps = GetInstantProperty(owner, 'ClimbWeb');
	if not prevProps then
		return;
	end
	
	SetInstantProperty(owner, 'ClimbWeb', nil);

	local actions = {};
	table.insert(actions, Result_PropertyUpdated('NotOccupy', prevProps.NotOccupy, owner));
	
	local mission = GetMission(owner);
	local dummyObj = GetUnit(mission, prevProps.DummyObjKey);
	if dummyObj then
		-- FallWeb 어빌리티를 써서 ClimbWeb 버프가 사라질 때 바로 적용되어야 하므로, sequential=false로 삭제함
		table.insert(actions, Result_DestroyObject(dummyObj, false, false));
	end
	
	-- FallWeb 어빌리티를 쓰지 않고, 턴이 지나서 사라지는 경우
	local ability_FallWeb = GetAbilityObject(owner, 'FallWeb');
	if ability_FallWeb and buff.Life <= 0 then
		local ownerPos = GetPosition(owner);
		local range = CalculateRange(owner, ability_FallWeb.TargetRange, ownerPos);
		local candidate = table.filter(range, function(pos)
			local obj = GetObjectByPosition(mission, pos);
			return (not obj) or (obj == owner);
		end);
		candidate = table.shuffle(candidate);
		table.sort(candidate, function(lhs, rhs)
			return GetDistance3D(lhs, ownerPos) < GetDistance3D(rhs, ownerPos);
		end);
		
		local targetPos = (#candidate > 0) and candidate[1] or ownerPos;
		table.insert(actions, Result_UseAbility(owner, ability_FallWeb.name, targetPos, {}, true));
	end
	
	return unpack(actions);
end
function Buff_BeingFished_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	local prevProps = GetInstantProperty(owner, 'BeingFished');
	if not prevProps then
		return;
	end
	
	SetInstantProperty(owner, 'BeingFished', nil);

	local actions = {};
	table.insert(actions, Result_PropertyUpdated('NotOccupy', prevProps.NotOccupy, owner));
	
	local mission = GetMission(owner);
	local dummyObj = GetUnit(mission, prevProps.DummyObjKey);
	if dummyObj then
		-- FallWeb 어빌리티를 써서 ClimbWeb 버프가 사라질 때 바로 적용되어야 하므로, sequential=false로 삭제함
		table.insert(actions, Result_DestroyObject(dummyObj, false, false));
	end	
	return unpack(actions);
end
function Buff_Burrow_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	
	local prevProps = GetInstantProperty(owner, 'Burrow');
	if not prevProps then
		return;
	end
	
	SetInstantProperty(owner, 'Burrow', nil);

	local actions = {};

	local mission = GetMission(owner);
	if prevProps.DummyObjKey then
		local dummyObj = GetUnit(mission, prevProps.DummyObjKey);
		if dummyObj then
			-- FallWeb 어빌리티를 써서 ClimbWeb 버프가 사라질 때 바로 적용되어야 하므로, sequential=false로 삭제함
			table.insert(actions, Result_DestroyObject(dummyObj, false, false));
		end
	end

	table.insert(actions, Result_PropertyUpdated('NotOccupy', prevProps.NotOccupy, owner));
	
	-- 턴이 다 지나서 사라지는 경우
	if buff.Life <= 0 then
		local subActions = { Buff_Burrow_InvokeDisableDigging(buff, owner, ds, false) };
		table.append(actions, subActions);
	end
	
	-- 재접속 시의 숨김 처리 해제
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routineKey = buff.name..'Hide'..objKey;
	UnregisterConnectionRestoreRoutine(mid, routineKey);
	
	return unpack(actions);
end
function Buff_Burrow_InvokeDisableDigging(buff, owner, ds, clearDummyObj)
	local disableAbility = GetAbilityObject(owner, 'Digging_Disable');
	local attackAbility = GetAbilityObject(owner, 'BurrowAmbush');
	if not disableAbility or not attackAbility then
		return;
	end
	
	local actions = {};
	local mission = GetMission(owner);
	-- 흔적 지우기
	if clearDummyObj then
		local prevProps = GetInstantProperty(owner, 'Burrow');
		if prevProps and prevProps.DummyObjKey then
			local dummyObj = GetUnit(mission, prevProps.DummyObjKey);
			if dummyObj then
				table.insert(actions, Result_DestroyObject(dummyObj, false, true));
			end
			prevProps.DummyObjKey = nil;
			SetInstantProperty(owner, 'Burrow', prevProps);
		end
	end
	-- 나올 위치 선정
	local ownerPos = GetPosition(owner);
	local rangeType = attackAbility.TargetRange;
	local range = CalculateRange(owner, rangeType, ownerPos);
	local candidate = table.filter(range, function(pos)
		local obj = GetObjectByPosition(mission, pos);
		if obj and obj ~= owner then
			return false;
		end
		-- 타일 체크
		local tileType = GetTileType(mission, pos);
		for _, cls in ipairs(disableAbility.DisabledOnTile) do
			if IsSubTileType(tileType, cls.Type) then
				return false;
			end
		end
		return true;
	end);
	candidate = table.shuffle(candidate);
	table.sort(candidate, function(lhs, rhs)
		return GetDistance3D(lhs, ownerPos) < GetDistance3D(rhs, ownerPos);
	end);
	local needDead = false;
	if #candidate == 0 then
		-- 사망 처리 후 부활할 수 있으므로, 빈 자리를 우선해서 뽑는다.
		candidate = table.filter(range, function(pos)
			local obj = GetObjectByPosition(mission, pos);
			if obj then
				return false;
			end
			return true;
		end);
		candidate = table.shuffle(candidate);
		table.sort(candidate, function(lhs, rhs)
			return GetDistance3D(lhs, ownerPos) < GetDistance3D(rhs, ownerPos);
		end);
		-- 일단 빈 자리로 올라온 뒤에 사망해야지...
		needDead = true;
	end
	local movePos = candidate[1] or ownerPos;
	
	local targetPos = nil;
	if not needDead then
		local targetPosRange = CalculateRange(owner, 'Diamond1_Attack', movePos);
		targetPosRange = table.filter(targetPosRange, function(targetPos)
			if IsSamePosition(targetPos, movePos) then
				return false;
			end
			local target = GetObjectByPosition(mission, targetPos);
			if not target or not IsEnemy(owner, target) then
				return false;
			end
			return true;
		end);
		if #targetPosRange > 0 then 
			targetPosRange = table.shuffle(targetPosRange);
			targetPos = targetPosRange[1];
		end	
	end
	
	-- 현재 위치가 아니면 위치 이동
	if not IsSamePosition(movePos, ownerPos) and not targetPos then
		local setPos = Result_SetPosition(owner, movePos, nil, nil, ownerPos);
		setPos.blink = true;
		table.insert(actions, setPos);
	end
	-- 공격 대상이 있으면 공격, 아니면 해제
	if targetPos then
		local attackAction = Result_UseAbility(owner, attackAbility.name, targetPos, {}, true);
		attackAction.free_action = true;
		table.insert(actions, attackAction);
	else
		local disableAction = Result_UseAbility(owner, disableAbility.name, movePos, {}, true);
		disableAction.free_action = true;
		table.insert(actions, disableAction);
	end
	-- 사망 처리
	if needDead then
		table.insert(actions, Result_DirectingScript(function(mid, ds, args)
			local actions = {};
			local damage, reasons = ApplyDamageTest(owner, owner.MaxHP, 'Buff');
			local isDead = owner.HP <= damage;
			local isFocus = true;
			DirectDamageByType(ds, owner, buff.name, owner.MaxHP, owner.HP - damage, isFocus, isDead, nil, 0);
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
			AddBuffDamageChat(ds, owner, buff, damage);
			table.insert(actions, Result_Damage(owner.MaxHP, 'Normal', 'Hit', owner, owner, 'Buff', 'Etc', buff));
			return unpack(actions);
		end, nil, true, true));
	end
	return unpack(actions);
end
function Buff_TriggerBuffCommon_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	local actions = {};
	local abilityList = GetAllAbility(owner, false, true);
	for _, ability in ipairs(abilityList) do
		local buffName = GetWithoutError(ability.ApplyTargetBuff, 'name');
		if buffName and buffName == buff.name then
			local coolTime = ability.CoolTime + 1;
			UpdateAbilityPropertyActions(actions, owner, ability.name, 'Cool', math.max(coolTime, 0));
		end
	end
	return unpack(actions);
end
function Buff_TriggerBuffCommon_BuffRemoved2(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	local actions = {};
	local buffKeyList = {'ApplyTargetBuff', 'ApplyTargetSubBuff'};
	local abilityList = GetAllAbility(owner, false, true);
	for _, ability in ipairs(abilityList) do
		for _, key in ipairs(buffKeyList) do
			local buffName = GetWithoutError(ability[key], 'name');
			if buffName and buffName == buff.name then
				local coolTime = ability.CoolTime + 1;
				UpdateAbilityPropertyActions(actions, owner, ability.name, 'Cool', math.max(coolTime, 0));
				break;
			end
		end
	end
	return unpack(actions);
end
function Buff_Flow_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Buff ~= buff then
		return;
	end
	local mid = GetMissionID(owner);
	local particleKey = 'FlowAlertArea_'..GetObjKey(owner);
	UnregisterConnectionRestoreRoutine(mid, particleKey);
	ds:MissionVisualArea_AddCustomMulti(particleKey, nil, nil, false);
	SetInstantProperty(owner, 'FlowAlreadyHitSet', nil);
end
function Buff_ObjectFreezer_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = buff.name..'ObjectFreezer'..objKey;
	ds:ReleasePose(objKey, 'None');
	UnregisterConnectionRestoreRoutine(mid, routinekey);
end
function Buff_VindictiveSpirit_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner 
		or eventArg.Buff ~= buff
		or buff.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	-- 연출
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	-- 모든 긍정적인 효과 삭제
	local removeBuffList = GetBuffType(owner, 'Buff');
	-- 버프 해제 면역
	local immuneMastery = GetMasteryMasteredImmuneRemoveBuff(GetMastery(owner));
	if immuneMastery and #removeBuffList > 0  then
		MasteryActivatedHelper(ds, immuneMastery, owner, 'ImmuneRemoveBuff');
		removeBuffList = {};
	end
	for _, buff in ipairs(removeBuffList) do
		InsertBuffActions(actions, owner, owner, buff.name, -buff.Lv);
		ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
	end
	-- 랜덤 정신적인 상태 이상 추가
	local buffClsList = GetClassList('Buff');
	local badMentalBuffList = Linq.new(GetClassList('Buff_Negative'))
		:select(function(pair) return pair[1]; end)
		:where(function(buffName) return buffClsList[buffName].SubType == 'Mental'; end)
		:toList();
	local buffPicker = RandomBuffPicker.new(owner, badMentalBuffList);
	local b = buffPicker:PickBuff();
	if b then
		InsertBuffActions(actions, owner, owner, b, 1);
	end
	return unpack(actions);
end
function Buff_Taming_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	RaiseHateCustom(owner, 'Taming', -100);
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = 'Taming_'..objKey;
	UnregisterConnectionRestoreRoutine(mid, routinekey);
end
function Buff_Communicating_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	RaiseHateCustom(owner, 'Taming', -100);
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = 'Communicating_'..objKey;
	UnregisterConnectionRestoreRoutine(mid, routinekey);
end
function Buff_Occupying_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = 'Occupying_'..objKey;
	UnregisterConnectionRestoreRoutine(mid, routinekey);
end
function Buff_Petrifaction_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local actions = {};
	-- 엄폐 복원
	local defaultCoverInfo = owner.OccupyType.CoverInfo.name;
	table.insert(actions, Result_ChangeCoverInfo(owner, defaultCoverInfo));
	-- 매터리얼 복원
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routinekey = buff.name..'ChangeMaterial'..objKey;
	ds:ChangeMaterial(objKey, '', true);
	UnregisterConnectionRestoreRoutine(mid, routinekey);
	return unpack(actions);
end
-- 은신
function Buff_Stealth_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	-- 버프가 새로 걸리는 경우에는 발각되지 않음
	if eventArg.BuffAdded then
		return;
	end
	local actions = {};
	local detected = GetInstantProperty(owner, 'StealthDetected');
	if not detected then
		table.insert(actions, Result_FireWorldEvent('CloakingDetected', {Unit=nil, Target=owner, Type=buff.name, FindPos=GetPosition(owner)}));
	end
	SetInstantProperty(owner, 'StealthDetected', nil);
	return unpack(actions);
end
-- 부화 중
function Buff_Hatching_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff or buff.Life > 0 then
		return;
	end
	local hatchingTypeName = GetInstantProperty(owner, 'HatchingType');
	if not hatchingTypeName then
		return Result_DestroyObject(owner, true, true);	
	end
	local hatchingType = GetClassList('BeastHatching')[hatchingTypeName];
	if not hatchingType then
		return Result_DestroyObject(owner, true, true);	
	end
	
	-- 부화 타입 픽커
	local typePicker = RandomPicker.new();
	for _, info in ipairs(hatchingType.MonsterList) do
		typePicker:addChoice(info.Prob, info);
	end
	
	-- 부화 위치 픽커
	local mission = GetMission(owner);
	local ownerPos = GetPosition(owner);
	local targetRange = table.filter(CalculateRange(owner, 'Sphere3', ownerPos), function(pos)
		return not GetObjectByPosition(mission, pos);
	end);
	
	local posPicker = RandomPicker.new(false);
	for _, pos in ipairs(targetRange) do
		local dist = GetDistance3D(ownerPos, pos);
		local score = math.floor(1000 / math.max(dist, 1));
		posPicker:addChoice(score, pos);
	end
	
	ds:PlayParticle(GetObjKey(owner), '_BOTTOM_', 'Particles/Dandylion/Explosion_Egg', 2, false, false, true);

	-- HatchingCount 마리 부화
	local actions = {};
	local hatchingCount = GetInstantProperty(owner, 'HatchingCount') or 1;
	for i = 1, hatchingCount do
		local hatchingInfo = typePicker:pick();
		local monType = hatchingInfo.Type;
		local newObjKey = GenerateUnnamedObjKey(mission);
		local targetPos = posPicker:pick();
		if not targetPos then
			break;
		end
		
		local unitInitializeFunc = function(unit, arg)
			UNIT_INITIALIZER(unit, unit.Team);
		end;
		
		-- AI Customize
		local aiType = GetWithoutError(hatchingInfo, 'AI') or 'NormalMonsterAI';
		local team = '_draky_egg_hatching_'; -- 적당한 중립 팀
		local teamType = GetWithoutError(hatchingInfo, 'Team');
		if teamType == 'Giver' then
			team = GetTeam(giver);
		elseif teamType == 'Owner' then
			team = GetTeam(owner);
		end
		local createAction = Result_CreateMonster(newObjKey, monType, targetPos, team, unitInitializeFunc, {}, aiType, {}, true);
		ApplyActions(mission, { createAction }, false);
		local target = GetUnit(mission, newObjKey);
		if not target then
			break;
		end
		
		if not owner.BackgroundObject then
			ds:WorldAction(Result_PropertyUpdated('BackgroundObject', true, owner));
		end
		table.insert(actions, Result_DestroyObject(owner, true, true));
		
		-- 각인 / 증오
		if not IsDead(giver) then
			local addBuff = GetWithoutError(hatchingInfo, 'AliveBuff');
			if addBuff and addBuff ~= 'None' then
				InsertBuffActionsMultiGiver(actions, giver, target, addBuff, true, true);
			end
		else
			local addBuff = GetWithoutError(hatchingInfo, 'DeadBuff');
			if addBuff and addBuff ~= 'None' then
				InsertBuffActions(actions, target, target, addBuff, 1, true);
			end
		end
		-- 죽음의 선고
		local addBuff = GetWithoutError(hatchingInfo, 'Buff');
		if addBuff then
			InsertBuffActions(actions, target, target, addBuff, 1, true);
		end
		-- 바로 행동
		table.insert(actions, Result_PropertyUpdated('Act', 0, target, true, true));
	end
	
	-- 알 파괴
	local hatchedObject = GetInstantProperty(owner, 'HatchedObject');
	local unitInitializeFunc = function(unit, arg)
		UNIT_INITIALIZER_NON_BATTLE(unit, unit.Team);
	end;
	local createAction = Result_CreateObject(GenerateUnnamedObjKey(mission), hatchedObject, ownerPos, '_neutral_', unitInitializeFunc, {}, 'DoNothingAI', nil, true);
	createAction.sequential = true;
	ds:WorldAction(createAction);
	if not owner.BackgroundObject then
		ds:WorldAction(Result_PropertyUpdated('BackgroundObject', true, owner));
	end
	table.insert(actions, Result_DestroyObject(owner, true, true));
	
	return unpack(actions);
end
-- 주시
function Buff_BeholderVision_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	return Result_SightSharing(owner, GetTeam(giver), false, true);
end
-- 눈속임 - 변이
function Buff_ChangeTrickery_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local originalShape = GetInstantProperty(owner, buff.name);
	if not originalShape then
		return;
	end
	-- 복원 로직 해제
	local mid = GetMissionID(owner);
	local objKey = GetObjKey(owner);
	local routineKey = 'ChangeTrickery'..objKey;
	UnregisterConnectionRestoreRoutine(mid, routineKey);
	-- 연출 로직 (DamageConveyor에서 연출했으면 생략)
	if buff.DuplicateApplyChecker > 0 then
		return;
	end
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/powder_green', 1, false, false, true);
	local changeShapeID = ds:ChangeShape(objKey, originalShape, true);
	ds:SetCommandLayer(particleID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(particleID);
	ds:Connect(changeShapeID, particleID, 0.1);
end
-- 매복
function Buff_BurrowOverwatching_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.BuffName ~= 'Burrow' then
		return;
	end
	return Result_RemoveBuff(owner, buff.name, true);
end
-- 야수 소환
function Buff_SummonBeast_BuffRemoved(eventArg, buff, owner, giver, ds)
	-- Brainwashing 버프가 아니면 무시
	if not eventArg.Buff.Brainwashing then
		return;
	end
	-- 아직도 Brainwashing 상태이면 무시
	if GetBuffStatus(owner, 'Brainwashing', 'Or') then
		return;
	end
	local actions = {};
	if IsDead(giver) then
		-- 소환 해제 or 소환 유지(독립 훈련 or 충성적)
		ApplySummonBeastStandAloneActions(actions, owner, giver);
	end
	return unpack(actions);
end
-- 기계 소환
function Buff_SummonMachine_BuffRemoved(eventArg, buff, owner, giver, ds)
	-- Brainwashing 버프가 아니면 무시
	if not eventArg.Buff.Brainwashing then
		return;
	end
	-- 아직도 Brainwashing 상태이면 무시
	if GetBuffStatus(owner, 'Brainwashing', 'Or') then
		return;
	end
	local actions = {};
	if IsDead(giver) then
		-- 소환 해제
		ApplyUnsummonMachineActions(actions, giver, owner);
	else
		local controlCount = #GetMachineListUnderControl(giver);
		local controlLimit = GetMachineControlLimit(giver);
		if controlCount > controlLimit then
			-- 제어 가능한 기계 숫자가 모자르면 소환 해제
			ApplyUnsummonMachineActions(actions, giver, owner);
		end
	end
	return unpack(actions);
end
-- 승격
function Buff_Promotion_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local actions = {};
	local addLv = -buff.ApplyAmount;
	table.insert(actions, Result_PropertyAdded('Lv', addLv, owner));
	table.insert(actions, Result_PropertyAdded('PromotionLv', addLv, owner));
	return unpack(actions);
end
-- 물 감옥
function Buff_WaterJail_BuffRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Buff ~= buff then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 유닛 이동 시작 [UnitMoveStarted]
----------------------------------------------------------------------------
-- 소환된 야수
function Buff_SummonBeast_UnitMoveStarted(eventArg, buff, owner, giver, ds)
	if not owner.PreBattleState
		or not eventArg.Unit.PreBattleState
		or GetObjKey(eventArg.Unit) ~= GetInstantProperty(owner, 'SummonMaster') then
		return;
	end
	
	local prevPos = GetPosition(eventArg.Unit);
	
	SetPosition(eventArg.Unit, eventArg.Position);
	local movePos = GetMovePosition(owner, eventArg.Position, 3, nil, 30);
	SetPosition(eventArg.Unit, prevPos);
	
	local move = ds:Move(GetObjKey(owner), movePos);
	
	if eventArg.MoveID then
		ds:Connect(move, eventArg.MoveID, 0);
	else
	
	end
	return Result_TurnEnd(owner, true);
end
--------------------------------------------------------------------------------
-- 유닛 이동 [UnitMoved] Unit, BeginPosition, Position, Path, StraightPath, MoveID, IsDash, MovingForAbility, Invoker, MovingForDirect, MoveIdentifier
----------------------------------------------------------------------------
-- 수풀 은신
function Buff_Stealth_Bush_UnitMoved(eventArg, buff, owner, giver, ds)
	local exposed = false;
	for _, pos in ipairs(eventArg.Path) do
		local hidden = (function()
			local fieldEffects = GetFieldEffectByPosition(owner, pos);
			for __, fe in ipairs(fieldEffects) do
				for ___, affector in ipairs(fe.Owner.BuffAffector) do
					if affector.name == 'Bush' then
						return true;
					end
				end
			end
			return false;
		end)();
		if not hidden then
			exposed = true;
			break;
		end
	end
	
	if not exposed then
		return;
	end
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
	return Result_RemoveBuff(owner, buff.name, true);
end
-- 위장
function Buff_Camouflage_UnitMoved(eventArg, buff, owner, giver, ds)
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
	return Result_RemoveBuff(owner, buff.name, true);
end
-- 순찰
function Buff_Patrol_UnitMoved(eventArg, buff, owner, giver, ds)
	local actions = {};
	local myMove = owner == eventArg.Unit;
	local patrolAvoidTargets = GetInstantProperty(owner, 'PatrolAvoidTargets') or {};
	if myMove then
		table.append(actions, Linq.new(patrolAvoidTargets)
			:select(function(data) 
				return Result_FireWorldEvent('PatrolAvoided', {Unit = data[1], Buff = buff}, GetUnit(owner, data[1])) 
			end)
			:toList());
		patrolAvoidTargets = nil;
	else
		local objKey = GetObjKey(eventArg.Unit);
		if not patrolAvoidTargets[objKey] then
			return;
		end
		table.insert(actions, Result_FireWorldEvent('PatrolAvoided', {Unit = objKey, Buff = buff}, GetUnit(owner, objKey)));
		patrolAvoidTargets[objKey] = nil;
		if table.empty(patrolAvoidTargets) then
			patrolAvoidTargets = nil;
		end
	end
	SetInstantProperty(owner, 'PatrolAvoidTargets', patrolAvoidTargets);
	return unpack(actions);
end	
-- 화합물 만들기
function Buff_MakeConcoction_UnitMoved(eventArg, buff, owner, giver, ds)
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	return unpack(actions);
end
function Buff_Trick_UnitMoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner and GetRelation(owner, eventArg.Unit) ~= 'Enemy' then
		return;
	end
	local mission = GetMission(owner);
	local enemyCount = 0;
	local myPos = GetPosition(owner);
	for i, pos in ipairs(CalculateRange(owner, 'Sphere6', myPos)) do
		local obj = GetObjectByPosition(mission, pos);
		if obj and GetRelation(owner, obj) == 'Enemy' then
			enemyCount = enemyCount + 1;
		end
	end
	if enemyCount >= 3 then
		return Result_RemoveBuff(owner, buff.name);
	end
end
function Direct_RescueHealthCitizen(mid, ds, args)
	local owner = args.Owner;
	local savior = args.Savior;
	local removeBuff = args.RemoveBuff;
	local pos = args.Position;
	local civilMsg = args.CivilMessage or 'Rescued';
	
	local unitKey = GetObjKey(owner);
	local saviorKey = GetObjKey(savior);
	local curPos = GetPosition(owner);
	ds:HideBattleStatus(unitKey);
	
	local ownerCamMove = ds:ChangeCameraTarget(unitKey, '_SYSTEM_', false, true, 1);
	local rotateLook = ds:LookAt(unitKey, saviorKey);
	local removeBuffCmd = ds:WorldAction(Result_RemoveBuff(owner, removeBuff), true);
	local playParticleCmd = ds:PlayParticlePosition('Particles/Dandylion/Rescue', curPos.x, curPos.y, curPos.z, 1, true);
	local imID = ds:UpdateInteractionMessage(unitKey, 'Rescue', owner.Info.name);
	local playSoundID = ds:PlaySound('Success.wav', 'Layout', 1);
	local civilMessage = ds:UpdateBalloonCivilMessage(unitKey, civilMsg, owner.Info.AgeType);
	-- 뭐가 되었던 간에 이제 사라질 놈이 오브젝티브 마커를 달고 이동하면 이상하니 없애버린다.
	local hideObjectMarker = ds:HideObjectMarker(unitKey);

	ds:Connect(hideObjectMarker, ownerCamMove, 0);
	ds:Connect(removeBuffCmd, ownerCamMove, 0);
	ds:Connect(playParticleCmd, ownerCamMove, 0);
	ds:Connect(imID, ownerCamMove, -1);
	ds:Connect(playSoundID, imID, 0.25);
	ds:Connect(rotateLook, imID, 1);
	ds:Connect(civilMessage, imID, 1);
	ds:Move(unitKey, pos, false, false, '', 0, 0, false, 1, false, true);
	ds:Sleep(3);
	
	local invalidPos = InvalidPosition();
	local moveId = ds:Move(GetObjKey(owner), invalidPos, true, true, '', 0, 0, false, 1, true, nil, nil, true);
	local moveAction = Result_SetPosition(owner, invalidPos);
	moveAction._ref = moveId;
	moveAction._ref_offset = 0;
	ds:WorldAction(moveAction, true);
	
	return Result_DestroyObject(owner, false, true);
end
function RescueHealthCitizen(owner, savior, ds, removeBuff, civilMsg)
	local pos = nil;
	local retreatPosition = GetInstantProperty(owner, 'RetreatPosition');
	if retreatPosition and retreatPosition.x ~= -1 and retreatPosition.y ~= -1 and retreatPosition.z ~= -1 then
		-- 튜토리얼시 정확한 위치로 이동을 해야하는데 --
		pos = retreatPosition;
	else
		pos = FindAIMovePosition(owner, {FindMoveAbility(owner)}, function (self, adb)
			return adb.MoveDistance;	-- 가장 멀리 갈 수 있는 아무데나
		end, {}, {});
	end
	
	local company = nil;
	if savior then
		company = GetCompany(savior);
	end
	local actions = {};
	table.insert(actions, Result_FireWorldEvent('CitizenRescuing', {Unit=owner, Savior=savior, Company=company}));
	table.insert(actions, Result_DirectingScript('Direct_RescueHealthCitizen', {Owner = owner, Savior = savior, RemoveBuff = removeBuff, Position = pos, CivilMessage = civilMsg}));
	table.insert(actions, Result_FireWorldEvent('CitizenRescued', {Unit=owner, Savior=savior, Company=company}));
	return unpack(actions);
end
function Buff_Rescue_UnitMoved(eventArg, buff, owner, giver, ds)
	local playerUnit = nil;
	if eventArg.Unit ~= owner then
		if GetOriginalTeam(eventArg.Unit) ~= 'player' then	-- 플레이어 팀을 어떻게 특정하지.. 흠
			return;
		end
		if GetDistance3D(eventArg.Position, GetPosition(owner)) > 1.8 then
			return;
		end
		if GetActionController(eventArg.Unit) ~= 'None' then
			return;
		end
		playerUnit = eventArg.Unit;
	else
		local nearObjects = GetNearObject(owner, 1.8);
		local playerUnits = table.filter(nearObjects, function(obj)
			return GetOriginalTeam(obj) == 'player' and GetActionController(obj) == 'None'	-- 플레이어 팀을 어떻게 특정하지.. 흠
		end);
		if #playerUnits == 0 then
			return;
		end
		playerUnit = playerUnits[1];
	end
		
	AddUnitStats(playerUnit, 'Rescue', 1, true);
	return RescueHealthCitizen(owner, playerUnit, ds, buff.name);
end
function Buff_Rescue_UnitTeamChanged(eventArg, buff, owner, giver, ds)
	if eventArg.Unit == owner or eventArg.Team ~= 'player' then	-- 플레이어 팀을 어떻게 특정하지.. 흠
		return;
	end
	if GetDistance3D(GetPosition(eventArg.Unit), GetPosition(owner)) > 1.8 then
		return;
	end	
	if GetActionController(eventArg.Unit) ~= 'None' then
		return;
	end
	local playerUnit = eventArg.Unit;
	AddUnitStats(playerUnit, 'Rescue', 1, true);
	return RescueHealthCitizen(owner, playerUnit, ds, buff.name);
end
function Buff_Rescue_UnitTurnStart(eventArg, buff, owner, giver, ds)
	if eventArg.Unit == owner or GetOriginalTeam(eventArg.Unit) ~= 'player' then	-- 플레이어 팀을 어떻게 특정하지.. 흠
		return;
	end
	if GetDistance3D(GetPosition(eventArg.Unit), GetPosition(owner)) > 1.8 then
		return;
	end	
	if GetActionController(eventArg.Unit) ~= 'None' then
		return;
	end
	local playerUnit = eventArg.Unit;
	AddUnitStats(playerUnit, 'Rescue', 1, true);
	return RescueHealthCitizen(owner, playerUnit, ds, buff.name);
end
function Buff_FakeRescue_UnitMoved(eventArg, buff, owner, giver, ds)
	if GetOriginalTeam(eventArg.Unit) ~= 'player' then	-- 플레이어 팀을 어떻게 특정하지.. 흠
		return;
	end
	
	if GetDistance3D(eventArg.Position, GetPosition(owner)) > 1.8 then
		return;
	end
	
	ds:UpdateBattleEvent(GetObjKey(owner), 'GetWord', { Color = 'Yellow', Word = 'UnleashedCamouflage' })
	ds:Sleep(2);

	-- 몬스터로 대상을 바꿈
	local pos = GetPosition(owner);
	ds:PlayParticlePosition('Particles/Dandylion/UnleashedCamouflage', pos.x, pos.y, pos.z, 1, true);
	
	local newObjKey = GenerateUnnamedObjKey(GetMission(owner));
	local fakeObject = GetInstantProperty(owner, 'FakeObject');
	local unitInitializeFunc = function(unit, arg)
		SetInstantProperty(unit, 'MonsterType', fakeObject);
		UNIT_INITIALIZER(unit, unit.Team);
		AddBuff(unit, 'FakeRescueRevealed', 1, unit);
	end;
	local createAction = Result_CreateObject(newObjKey, fakeObject, pos, 'fake_citizen', unitInitializeFunc, {}, 'SuperAggressive', nil);
	createAction.sequential = true;
	return Result_DestroyObject(owner, false, true), createAction;
end
function Buff_DetectingWatchtower_UnitMovedSingleStep(eventArg, buff, owner, giver, ds)
	if buff.DuplicateApplyChecker > 0 then
		return;
	end
	local relation = GetRelation(owner, eventArg.Unit);
	if relation ~= 'Enemy' then	-- 순찰중인 같은팀에 의해서는 안일남
		return;
	end

	local pos = eventArg.Position;
	if not IsInSight(owner, pos, true) then
		return;
	end
	
	buff.DuplicateApplyChecker = 1;
	return Buff_Patrol_FindEnemy(owner, eventArg.Unit, pos, ds, false, eventArg.MoveID, true, 'Patrol', nil, eventArg.EndPosition);
end
function Buff_SupportMoving_UnitMoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return true;
	end
	return Result_RemoveBuff(owner, buff.name, true);
end
function Buff_InjuredRescue_UnitMoved(eventArg, buff, owner, giver, ds)
	if buff.DuplicateApplyChecker > 0 then
		return;
	end
	if GetTeam(eventArg.Unit) ~= 'player' then
		return;
	end
	local movePos = eventArg.Position;
	local ownerPos = GetPosition(owner);
	local distance = GetDistance3D(ownerPos, movePos);
	if distance > 4 then
		return;
	end
	local playId = ds:UpdateBalloonCivilMessage(GetObjKey(owner), 'FindInjuredRescue', owner.Info.AgeType);
	ds:SetCommandLayer(playId, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(playId);
	buff.DuplicateApplyChecker = 1;
end
function Buff_Taming_UnitMoved(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'TamingTarget');
	if (eventArg.Unit ~= owner and GetObjKey(eventArg.Unit) ~= targetKey) then
		return;
	end
	local movePos = eventArg.Position;
	if IsInSight(owner, movePos, true) then
		local objKey = GetObjKey(owner);
		ds:ReleasePose(objKey, 'None');
		ds:LookAt(objKey, targetKey, true);
		ds:PlayPose(objKey, 'TameStart', 'TameStd', false, 'TameStdIdle', true);
		return;
	end
	local target = nil;
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	return Result_FireWorldEvent('TamingFailed', {Unit=owner, Target=target}, nil, true);
end
function Buff_Communicating_UnitMoved(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'CommunicatingTarget');
	if (eventArg.Unit ~= owner and GetObjKey(eventArg.Unit) ~= targetKey) then
		return;
	end
	local movePos = eventArg.Position;
	if IsInSight(owner, movePos, true) then
		local objKey = GetObjKey(owner);
		ds:ReleasePose(objKey, 'None');
		ds:LookAt(objKey, targetKey, true);
		ds:PlayPose(objKey, 'TameStart', 'TameStd', false, 'TameStdIdle', true);
		return;
	end
	local target = nil;
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	return Result_FireWorldEvent('CommunicatingFailed', {Unit=owner, Target=target}, nil, true);
end
function Buff_Occupying_UnitMoved(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'InteractionTarget');
	local target = nil;
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	return Result_FireWorldEvent('OccupyingFailed', {Unit=owner, Target=target}, owner, true);
end
function Buff_RepairInteraction_UnitMoved(eventArg, buff, owner, giver, ds)
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	table.insert(actions, Result_PropertyUpdated('Act', 0, owner, true, true));
	return unpack(actions);
end
-- 재빠른 티마
function Buff_Tima_ChaserMode_UnitMoved(eventArg, buff, owner, giver, ds)
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
		
		satisfied = totalPathLength > buff.ApplyAmount;
	else
		satisfied = eventArg.IsDash;
	end
	if not satisfied then
		return;
	end
	
	local actions = {};
	local applyAct = -1 * buff.ApplyAmount2;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	if not eventArg.MovingForDirect then
		ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	end
	AddBuffEventChat(ds, owner, buff);
	
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 유닛 이동 중 [UnitMovedSingleStep]
----------------------------------------------------------------------------
-- 연막 생성기
function Buff_Generator_Smoke_UnitMovedSingleStep_Self(eventArg, buff, owner, giver, ds)
	if IsDead(owner) then
		return;
	end
	local eventCmd = ds:SubscribeFSMEvent(GetObjKey(owner), 'StepForward', 'CheckUnitArrivePosition', {CheckPos=eventArg.Position}, true, true);
	if eventArg.MoveID and ds:GetRefID(eventArg.MoveID) ~= eventArg.MoveID then
		ds:Connect(eventCmd, eventArg.MoveID, 0);		-- 루프를 만들어서 교체를 시키려고
		ds:Connect(eventArg.MoveID, eventCmd, 0);
	else
		ds:SetConditional(eventCmd);
	end
	local action = Buff_Generator_Smoke_Activate(owner, eventArg.Position);
	action._ref = eventCmd;
	action._ref_offset = -1;
	
	return action;
end
-- 은신
function Buff_Stealth_UnitMovedSingleStep(eventArg, buff, owner, giver, ds)
	return Buff_Stealth_UnitMoveTest(eventArg, buff, owner, giver, ds, eventArg.MoveID);
end
function GetCloakingDetectTestDist(unit)
	local rangeCls = GetClassList('Range')[unit.CloakingDetectRange];
	if rangeCls.Type == 'Dot' then
		return 1;
	elseif rangeCls.Type == 'Box' then
		return rangeCls.Distance * 1.42; -- > 1.414
	elseif rangeCls.Type == 'Sphere' then
		return rangeCls.Radius + 0.4;
	elseif rangeCls.Type == 'Sight' then
		return unit.SightRange + 0.4;
	end
end
function Buff_Stealth_UnitMoveTest(eventArg, buff, owner, giver, ds, moveID)
	local myMove = owner == eventArg.Unit;
	local relation = GetRelation(owner, eventArg.Unit);
	if not myMove and relation ~= 'Enemy' then		-- 관계없는 애들에 의해서는 안일남
		return;
	end
	if eventArg.Unit.HP <= 0 or owner.HP <= 0 then
		return;
	end
	-- 돌진 공격 시엔 미리 사라지지 않게
	if myMove and GetInstantProperty(owner, 'MovingForAbility') then
		return;
	end
	local isDetected = false;
	local findPos = nil;
	local findObj = nil;
	local mission = GetMission(owner);

	if myMove then
		local prevPos = GetPosition(owner);
		local pos = eventArg.Position;
		SetPosition(owner, pos);	-- 이동 경로를 돌면서 적들을 발견하는지 체크
		for j, unit in ipairs(GetAllUnit(mission)) do
			local unitPos = GetPosition(unit);
			if (function()
				if unit == owner then
					return false;
				end
				local rel = GetRelation(owner, unit);
				if rel ~= 'Enemy' then
					return false;
				end
				if GetBuffStatus(unit, 'Unconscious', 'Or') then
					return false;
				end
				-- 계산 비용 절감을 위한 선처리
				local testDist = GetCloakingDetectTestDist(unit);
				if testDist and GetDistance2D(pos, unitPos) > testDist then
					return false;
				end
				local detectRange = CalculateRange(unit, unit.CloakingDetectRange, unitPos);
				if not BuffHelper.IsPositionInRange(pos, detectRange) then
					return false;
				end
				return true;
			end)() then
				isDetected = true;
				findPos = pos;
				findObj = unit;
				break;
			end
		end
		SetPosition(owner, prevPos);
	else
		local unit = eventArg.Unit;
		local pos = eventArg.Position;
		local ownerPos = GetPosition(owner);
		if (function()
			if GetBuffStatus(unit, 'Unconscious', 'Or') then
				return false;
			end
			-- 계산 비용 절감을 위한 선처리
			local testDist = GetCloakingDetectTestDist(unit);
			if testDist and GetDistance3D(ownerPos, pos) > testDist then
				return false;
			end
			local detectRange = CalculateRange(unit, unit.CloakingDetectRange, pos);
			if not BuffHelper.IsPositionInRange(ownerPos, detectRange) then
				return false;
			end
			return true;
		end)() then
			isDetected = true;
			findPos = pos;
			findObj = unit;
		end
	end
	if not isDetected then
		return;
	end
	if moveID == nil then
		findPos = nil;
	end
	local masteryTable = GetMastery(owner);
	-- 살금 살금/슬금 슬금/소음 제어 장치 (소음 제어 장치는 거리 제한과 상관없이 적용)
	local mastery_StealthyFootsteps = GetMasteryMasteredLikeStealthyFootsteps(masteryTable);
	if myMove and mastery_StealthyFootsteps and (mastery_StealthyFootsteps.CountChecker > 0 or mastery_StealthyFootsteps.name == 'Module_NoiseControl') then
		return Mastery_StealthyFootsteps_Invoked(eventArg, mastery_StealthyFootsteps, owner, ds, findPos);
	end
	return Buff_Stealth_Detected(owner, findObj, findPos, ds, myMove, moveID, buff.name);
end
function Buff_Stealth_Detected(owner, findObj, findPos, ds, ownerMoved, moveID, buffType)
	local findObjectKey = GetObjKey(findObj);
	local ownerKey = GetObjKey(owner);
	local targetKey = GetObjKey(findObj);
	local connectID = nil;
	local detectID = nil;
	
	local detectLevel = 0
	if HasBuff(findObj, 'Detecting') then
		detectLevel = 3;
	elseif HasBuff(findObj, 'Partrol') then
		detectLevel = 2;
	elseif HasBuff(findObj, 'Stand') then
		detectLevel = 1;
	end	
	local alertParticleName = string.format('Particles/Dandylion/Selection_EnemySight%d', detectLevel);
	
	local needReleaseFindObject = findPos ~= nil;
	if findPos then
		local moveObjectKey = (ownerMoved and ownerKey or findObjectKey);
		local eventCmd = ds:SubscribeFSMEvent(moveObjectKey, 'StepForward', 'CheckUnitArrivePosition', {CheckPos=findPos}, true, true);
		if moveID then
			ds:Connect(eventCmd, moveID, 0);
			ds:Connect(moveID, eventCmd, 0);
		else
			ds:SetConditional(eventCmd);
		end
		local visible = ds:EnableIf('TestObjectVisibleAndAliveMulti', {ObjectList = {ownerKey, findObjectKey}, Mode = 'Or'});
		ds:Connect(visible, eventCmd, -1);
		eventCmd = visible;
		local findObjPos = (ownerMoved and GetPosition(findObj) or findPos);
		local camMoveTime = 1;
		ds:Connect(ds:StopUpdate(ownerKey), eventCmd, -1);
		ds:Connect(ds:StopUpdate(findObjectKey), eventCmd, -1);
		
		local findObjCamMove = ds:ChangeCameraTarget(findObjectKey, '_SYSTEM_', false, false, camMoveTime);
		ds:Connect(findObjCamMove, eventCmd, -1);
		
		if not ownerMoved then
			connectID = findObjCamMove;
		else
			-- 발견자가 움직인게 아니라면 StopUpdate를 미리 풀고 대상을 바라봄
			-- 돌아보기 시작한후 0.1 초 후에 대상의 업데이트를 풀음.
			local rotateLook = ds:LookAt(findObjectKey, ownerKey);
			ds:Connect(rotateLook, findObjCamMove, -1);
			ds:Connect(ds:ContinueUpdate(findObjectKey), rotateLook, 0.1);
			connectID = rotateLook;
		end
		ds:TemporarySightWithThisAction(findObjPos, 1, eventCmd, -1, connectID, -1);
		
		local stopObjKey = ownerMoved and findObjectKey or ownerKey;
		local fObjKey = ownerMoved and ownerKey or findObjectKey;

		ds:Connect(ds:ShowAlertLine(fObjKey, stopObjKey, alertParticleName), findObjCamMove, -1);
		local sleepID = ds:Sleep(0.05);
		ds:Connect(sleepID, connectID, -1);
		
		local camMoveTime2 = 1;
		local ownerCamMove = ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false, camMoveTime2);
		ds:Connect(ownerCamMove, sleepID, -1);
		local ownerCamSleep = ds:Sleep(0.5);
		ds:Connect(ownerCamSleep, ownerCamMove, -1);
		connectID = ownerCamSleep;
		
		local detectedMessage = ds:UpdateBattleEvent(ownerKey, 'GetWordAliveOnly', { Color = 'Red', Word = 'CloakingDetected' });
		ds:Connect(detectedMessage, ownerCamMove, camMoveTime2 - 0.5);
		
		local buffDischargedID = ds:UpdateBattleEvent(ownerKey, 'BuffDischarged', { Buff = buffType });
		ds:Connect(buffDischargedID, detectedMessage, -1);
		
		if not ownerMoved then
			local continueID = ds:ContinueUpdate(findObjectKey);
			ds:Connect(continueID, connectID, -1);
		end
	end
	
	-- 발견 동작
	-- 소유자가 이동한 경우는 끝나고 연출.
	-- 그렇지 않은 경우는 이동과 동시에 연출
	local visible = ds:EnableIf('TestObjectVisibleAndAliveMulti', {ObjectList = {ownerKey, findObjectKey}, Mode = 'Or'});
	if connectID ~= nil then
		ds:Connect(visible, connectID, -1);
	end
	connectID = visible;
	if needReleaseFindObject then
		ds:Connect(ds:ContinueUpdate(ownerKey), connectID, -1);
	end	
	
	local actions = {};
	SetInstantProperty(owner, 'StealthDetected', true);
	table.insert(actions, Result_RemoveBuff(owner, buffType, true));
	table.insert(actions, Result_FireWorldEvent('CloakingDetected', {Unit=findObj, Target=owner, Type=buffType, FindPos=findPos}));
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 유닛 위치 변화 [UnitPositionChanged]
----------------------------------------------------------------------------
-- 수풀 은신
function Buff_Stealth_Bush_UnitPositionChanged(eventArg, buff, owner, giver, ds)
	local hidden = (function()
		local fieldEffects = GetFieldEffectByPosition(owner, eventArg.Position);
		for __, fe in ipairs(fieldEffects) do
			for ___, affector in ipairs(fe.Owner.BuffAffector) do
				if affector.name == 'Bush' then
					return true;
				end
			end
		end
		return false;
	end)();
	if hidden then
		return;
	end
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
	return Result_RemoveBuff(owner, buff.name, true);
end
function Buff_Generator_Smoke_UnitPositionChanged(eventArg, buff, owner, giver, ds)
	return Buff_Generator_Smoke_Activate(owner, eventArg.Position);
end
function Buff_Subordinate_UnitPositionChanged(eventArg, buff, owner, giver, ds)
	if GetObjKey(eventArg.Unit) ~= GetInstantProperty(owner, 'SummonMaster')
		or eventArg.NoEvent
		or not eventArg.Blink
		or not eventArg.MovingForDirect then
		return;
	end
	LogAndPrint('Buff_Subordinate_UnitPositionChanged - owner:', owner.name, GetObjKey(owner), ', eventArg.Unit:', eventArg.Unit.name, GetObjKey(eventArg.Unit), ', eventArg.Position:', eventArg.Position.x, eventArg.Position.y, eventArg.Position.z);
	if IsValidPosition(owner, eventArg.Position) then
		local prevPos = GetPosition(eventArg.Unit);
		SetPosition(eventArg.Unit, InvalidPosition());
		local movepos = GetNearestOccupiablePos(owner, eventArg.Position, true, false);
		SetPosition(eventArg.Unit, prevPos);
		LogAndPrint(' - prevPos:', prevPos, ', movepos:', movepos);
		-- 선 점유
		local curPos = GetPosition(owner);
		SetPosition(owner, movepos);
		-- 후 연출
		return Result_DirectingScript(function(mid, ds, args)
			SetPosition(owner, curPos);
			ds:Move(GetObjKey(owner), movepos, true);
		end, nil, true, true);
	end
end
function Buff_Stealth_UnitPositionChanged(eventArg, buff, owner, giver, ds)
	return Buff_Stealth_UnitMoveTest(eventArg, buff, owner, giver, ds, nil);
end
--------------------------------------------------------------------------------
-- 어빌리티 사용 [AbilityUsed]
----------------------------------------------------------------------------
-- 고드름
---@param eventArg abilityUsedEventArg
---@param buff buff
---@param owner unit
---@param giver unit
---@param ds any
function Buff_Icicles_AbilityUsed(eventArg, buff, owner, giver, ds)
	if buff.Lv ~= buff:MaxStack(owner) 
		or not IsGetAbilitySubType(eventArg.Ability, 'Ice') then
		return;
	end
	return Result_RemoveBuff(owner, buff.name, true, owner);
end
-- 위력 조절
---@param eventArg abilityUsedEventArg
---@param buff buff
---@param owner unit
---@param giver unit
---@param ds any
function Buff_MercyStrike_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	-- 연출용 메시지 처리
	if not HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.Target and HasBuff(targetInfo.Target, 'MercyStrike_Temp') then
			local b = GetBuff(targetInfo.Target, 'MercyStrike_Temp');
			if b.DuplicateApplyChecker > 0 then
				return true;
			end
		end
		return false;
	end) then
		return
	end

	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
end
-- 화합물 만들기
function Buff_MakeConcoction_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' or eventArg.Ability.HitRateType == 'Throw' then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	return unpack(actions);
end
-- 응축된 마력
--[[ 
SpellPower.DuplicateApplyChecker:
	bitwise flag
	1: 마력폭발 켜짐
	2: 유닛을 죽임
]]
function Buff_SpellPower_PreAbilityUsing(eventArg, buff, owner, giver, ds)
	buff.DuplicateApplyChecker = 0;
end
function Buff_SpellPower_AbilityUsed(eventArg, buff, owner, giver, ds)
	local actions = {};
	local removeBuff = (eventArg.Ability.Type == 'Attack' and IsGetAbilitySubType(eventArg.Ability, 'ESP')) or hasbit(buff.DuplicateApplyChecker, bit(1));
	local restoreBuff = hasbit(buff.DuplicateApplyChecker, bit(2));
	
	local nextBuffLv = buff.Lv;
	if removeBuff then
		-- 응축된 마력 해제
		nextBuffLv = 0;
		local masteryTable = GetMastery(owner);
		-- 마력 폭발
		local mastery_SpellExplosion = GetMasteryMastered(masteryTable, 'SpellExplosion');
		if mastery_SpellExplosion and hasbit(buff.DuplicateApplyChecker, bit(1)) then
			local applyAct = -1 * buff.Lv;
			local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly', nil, eventArg.Ability);
			if added then
				ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
			end
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		end
		-- 마력 해소
		local mastery_SpellRelease = GetMasteryMastered(masteryTable, 'SpellRelease');
		local ownerPos = GetPosition(owner);
		if mastery_SpellRelease 
			and HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
					return IsMeleeDistance(ownerPos, targetInfo.TargetPos)
				end) 
			then
			MasteryActivatedHelper(ds, mastery_SpellRelease, owner, 'AbilityUsed');
			-- 마력 노심
			local mastery_MagicCore = GetMasteryMastered(masteryTable, 'MagicCore');
			if mastery_MagicCore then
				local stepCount = math.floor(buff.Lv / mastery_SpellRelease.ApplyAmount);
				local addHP = math.floor(owner.MaxHP * stepCount * mastery_SpellRelease.ApplyAmount2 / 100);
				local reasons = {};
				addHP, reasons = AddActionRestoreHP(actions, owner, owner, addHP);
				ReasonToUpdateBattleEventMulti(owner, ds, reasons);
				MasteryActivatedHelper(ds, mastery_MagicCore, owner, 'AbilityUsed');
				if owner.HP < owner.MaxHP then
					DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false);
				end
				AddMasteryDamageChat(ds, owner, mastery_MagicCore, -1 * addHP);
			end
			-- 마력 강타
			local mastery_SpellStrike = GetMasteryMastered(masteryTable, 'SpellStrike');
			if mastery_SpellStrike then
				local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
					return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
				end);
				if hasAnyDead then
					MasteryActivatedHelper(ds, mastery_SpellStrike, owner, 'AbilityUsed');
					nextBuffLv = nextBuffLv + mastery_SpellRelease.ApplyAmount3;
				end
			end
			-- 마력 침식
			local mastery_SpellErosion = GetMasteryMastered(masteryTable, 'SpellErosion');
			if mastery_SpellErosion then
				local targetList = GetTargetListFromAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
					return IsEnemy(owner, targetInfo.Target) and targetInfo.MainDamage > 0 and targetInfo.DefenderState ~= 'Dodge' and not targetInfo.IsDead;
				end);
				if #targetList > 0 then
					MasteryActivatedHelper(ds, mastery_SpellErosion, owner, 'AbilityUsed');
					for _, target in ipairs(targetList) do
						InsertBuffActions(actions, owner, target, mastery_SpellRelease.SubBuff.name, 1, true);
					end
				end
			end
		end		
	end
	-- 마력 회수
	if restoreBuff then
		local addLv = math.floor(buff.Lv / 2);
		nextBuffLv = nextBuffLv + addLv;
	end
	-- 응축된 마력 레벨 조정
	local addLv = nextBuffLv - buff.Lv;
	InsertBuffActions(actions, owner, owner, buff.name, addLv, true);
	return unpack(actions);
end
function Buff_MotherNatureRage_AbilityUsed(eventArg, buff, owner, giver, ds)
	if buff.DuplicateApplyChecker > 0 or eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local battleEvent = {{Object = owner, EventType = 'MotherNatureRage'}};
	local config = eventArg.DirectingConfig or {};
	config.NoCamera = true;
	local retAction = Result_UseAbility(owner, eventArg.Ability.name, eventArg.PositionList[#(eventArg.PositionList)], {ReactionAbility = true, BattleEvents = battleEvent}, true, config);
	retAction._ref = eventArg.ActionID;
	retAction._ref_offset = -1;
	if config.Preemptive then
		retAction.nonsequential = true;
	end
	retAction.free_action = true;
	buff.DuplicateApplyChecker = buff.DuplicateApplyChecker + 1;
	return retAction;
end
function Buff_Outlaw_AbilityUsed(eventArg, buff, owner, giver, ds)
	if buff.DuplicateApplyChecker > 0 or eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local atLeastOneHit = false;
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if info.DefenderState ~= 'Dodge' then
				atLeastOneHit = true;
				break;
			end
		end
		if atLeastOneHit then
			break;
		end
	end
	
	if atLeastOneHit then
		return;
	end
	local battleEvent = {{Object = owner, EventType = 'Outlaw'}};
	local config = eventArg.DirectingConfig or {};
	config.NoCamera = true;
	local retAction = Result_UseAbility(owner, eventArg.Ability.name, eventArg.PositionList[#(eventArg.PositionList)], {ReactionAbility = true, BattleEvents = battleEvent}, true, config);
	retAction._ref = eventArg.ActionID;
	retAction._ref_offset = -1;
	if config.Preemptive then
		retAction.nonsequential = true;
	end
	retAction.free_action = true;
	buff.DuplicateApplyChecker = buff.DuplicateApplyChecker + 1;
	return retAction;
end
function Buff_Trick_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local hitEnemy = (function ()
		for i, targetInfos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
			for j, targetInfo in ipairs(targetInfos) do
				local rel = GetRelation(owner, targetInfo.Target);
				if rel == 'Enemy' then
					return true;
				end
			end
		end
		return false;
	end)();
	
	if not hitEnemy then
		return;
	end
	
	return Result_RemoveBuff(owner, buff.name);
end
function Buff_Berserker_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' or eventArg.Ability.ItemAbility then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.Lv, true);
	return unpack(actions);
end
---@param buff buff
---@param owner unit
---@param giver unit
---@param ds any
function Buff_Grimreaper_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner 
		or eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.ItemAbility then
		return;
	end
	
	local actions = {};
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if info.DefenderState ~= 'Dodge' and info.Target.HP > 0 then
				InsertBuffActions(actions, owner, info.Target, buff.AddBuff, 1, true);	
			end
		end
	end
	return unpack(actions);
end
function Buff_SecondImpact_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	return unpack(actions);
end
function Buff_LesserArtChain_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	local chainAbilityMap = GetInstantProperty(owner, 'LesserArtChainMapCache');
	if chainAbilityMap == nil then
		-- 체인 맵을 새로 계산
		chainAbilityMap = {};
		local chainCandidates = Set.new({'FlameDance', 'FlameShoot', 'FlameJumpKick', 'FlameCarriage', 'FlameStampKick', 'FlameBackJumpKick'});
		local chainCount = 2;
		local chainFrom = 'ResentmentOfRedLesserPanda';
		for i = #owner.Ability, 1, -1 do
			local curAbility = owner.Ability[i];
			if curAbility.Active and chainCandidates[curAbility.name] then
				chainAbilityMap[chainFrom] = {Ability = curAbility.name, ChainCount = chainCount};
				chainCount = chainCount + 1;
				chainFrom = curAbility.name;
			end
		end
		SetInstantProperty(owner, 'LesserArtChainMapCache', chainAbilityMap);
	end

	-- 언제든지 체인이 끊어지면 버프가 사리져야 함
	local removeBuff = Result_RemoveBuff(owner, buff.name, true);
	local chainData = chainAbilityMap[eventArg.Ability.name];
	if not chainData then
		return removeBuff;
	end
	local chainAbility = GetAbilityObject(owner, chainData.Ability);
	if not chainAbility then
		return removeBuff;
	end
	-- 대상 체크
	if #eventArg.PrimaryTargetInfos == 0 then
		return removeBuff;
	end
	local info = eventArg.PrimaryTargetInfos[1];
	local target = info.Target;
	if info.DefenderState == 'Dodge' or target.HP <= 0 then
		return removeBuff;
	end
	-- 범위 체크
	local range = CalculateRange(owner, chainAbility.TargetRange, GetPosition(owner));
	if not BuffHelper.IsPositionInRange(GetPosition(target), range) then
		return removeBuff;
	end
	-- 확률 체크
	local prob = 50;
	local masteryTable = GetMastery(owner);
	local mastery_LesserArt = GetMasteryMastered(masteryTable, 'LesserArt');
	local inevitable = false;
	if mastery_LesserArt then
		prob = prob + mastery_LesserArt.ApplyAmount;
		inevitable = true;
	end
	if not RandomTest(prob) then
		return removeBuff;
	end
	-- 어빌리티 사용
	local battleEvents = {{Object = owner, EventType = 'ChainAbility', Args = {ChainCount = chainData.ChainCount}}};
	local abilityAction = Result_UseAbilityTarget(owner, chainData.Ability, info.Target, {BattleEvents = battleEvents, Inevitable = inevitable}, true, {});
	abilityAction.free_action = true;

	return abilityAction;
end
function Buff_Bloodwalker_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	buff.DuplicateApplyChecker = 0;
end
function Buff_Hero_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	buff.DuplicateApplyChecker = 0;
end
function Buff_Luck_AbilityUsed_Exhausted(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	buff.DuplicateApplyChecker = 1;
end
function Buff_Luck_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local exhausted = false;
	if eventArg.Unit == owner then
		exhausted = true;
	elseif buff.DuplicateApplyChecker > 0 then
		exhausted = true;
	end
	
	if not exhausted then
		return;
	end
	
	-- 아이템 특성: 살수의 인장
	local masteryTable = GetMastery(owner);
	local mastery_Amulet_Killer = GetMasteryMastered(masteryTable, 'Amulet_Killer');
	if mastery_Amulet_Killer and mastery_Amulet_Killer.DuplicateApplyChecker == 0 then
		mastery_Amulet_Killer.DuplicateApplyChecker = 1;
	end

	return Result_RemoveBuff(owner, buff.name, true);
end
function Buff_CurseOfSword_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local killCount = 0;
	local killTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		if IsEnemy(owner, target) and target.HP <= 0 and not killTargets[targetKey] then
			killCount = killCount + 1;
			killTargets[targetKey] = true;
		end	
	end);
	if table.empty(killTargets) then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'BuffInvoked', { Buff = buff.name });
	-- 코스트
	for i = 1, killCount do
		local addCost = -1 * buff.Lv;
		local _, reasons = AddActionCost(actions, owner, addCost, true);
		ds:UpdateBattleEvent(ownerKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost });
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
	return unpack(actions);
end
-- 마법 가속
function Buff_MagicAcceleration_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' or not IsGetAbilitySubType(eventArg.Ability, 'ESP') then
		return;
	end
	local instantCost = eventArg.UserInfo.InstantCost;
	if instantCost <= 0 or owner.Cost <= 0 then
		return;	
	end
	local masteryTable = GetMastery(owner);
	local mastery_MagicControl = GetMasteryMastered(masteryTable, 'MagicControl');	
	if mastery_MagicControl then
		instantCost = instantCost - math.floor(instantCost * mastery_MagicControl.ApplyAmount2 / 100);
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	local eventID = ds:UpdateBattleEvent(ownerKey, 'BuffInvoked', { Buff = buff.name });
	if mastery_MagicControl then
		ds:Connect(ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery_MagicControl.name }), eventID, 0);
	end
	-- 코스트
	local addCost = -1 * instantCost;
	local _, reasons = AddActionCost(actions, owner, addCost, true);
	ds:Connect(ds:UpdateBattleEvent(ownerKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost }), eventID, 0);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons, eventID, 0);
	return unpack(actions);
end
-- 엔진 가속
function Buff_EngineBoost_AbilityUsed(eventArg, buff, owner, giver, ds)
	local instantCost = eventArg.UserInfo.InstantCost;
	if instantCost <= 0 or owner.Cost <= 0 then
		return;	
	end
	local masteryTable = GetMastery(owner);
	local actions = {};
	local ownerKey = GetObjKey(owner);
	local eventID = ds:UpdateBattleEvent(ownerKey, 'BuffInvoked', { Buff = buff.name });
	-- 코스트
	local addCost = -1 * instantCost;
	local _, reasons = AddActionCost(actions, owner, addCost, true);
	ds:Connect(ds:UpdateBattleEvent(ownerKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost }), eventID, 0);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons, eventID, 0);
	return unpack(actions);
end
-- 번개 갈기
function Buff_LightningMane_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' or not IsGetAbilitySubType(eventArg.Ability, 'Lightning') then
		return;
	end
	local instantCost = eventArg.UserInfo.InstantCost;
	if instantCost <= 0 or owner.Cost <= 0 then
		return;	
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	local eventID = ds:UpdateBattleEvent(ownerKey, 'BuffInvoked', { Buff = buff.name });
	-- 코스트
	local addCost = -1 * instantCost;
	local _, reasons = AddActionCost(actions, owner, addCost, true);
	ds:Connect(ds:UpdateBattleEvent(ownerKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost }), eventID, 0);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons, eventID, 0);
	
	local addCost = -10;
	if owner.Cost + addCost >= 0 then
		local _, reasons = AddActionCost(actions, owner, addCost, true);
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = addCost });
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	else
		table.insert(actions, Result_RemoveBuff(owner, buff.name));
	end
	return unpack(actions);
end
-- 오염수
function Buff_ContaminatedWater_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' or not IsGetAbilitySubType(eventArg.Ability, 'ESP')
		or owner.CostType.name ~= 'Vigor'
		or buff.Disabled then
		return;
	end
	local instantCost = eventArg.UserInfo.InstantCost;
	if instantCost <= 0 or owner.Cost <= 0 then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	local eventID = ds:UpdateBattleEvent(ownerKey, 'BuffInvoked', { Buff = buff.name });
	-- 코스트
	local addCost = -1 * instantCost;
	local _, reasons = AddActionCost(actions, owner, addCost, true);
	ds:Connect(ds:UpdateBattleEvent(ownerKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost }), eventID, 0);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons, eventID, 0);
	return unpack(actions);	
end
function Buff_Trance_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	-- 과충전 상태를 해제하는 SP 소모 어빌리티는 제외
	local comsumeSP = 0;
	if eventArg.Ability.SPAbility and (eventArg.Ability.SPFullAbility or eventArg.Ability.SP > 0) then
		comsumeSP = eventArg.UserInfo.InstantSP or 0;
	end
	if comsumeSP > 0 then
		return;
	end
	-- 그럴 일은 없지만 과충전 상태가 아니면 제외
	if owner.Overcharge <= 0 then
		return;
	end
	local killTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		if IsEnemy(owner, target) and target.HP <= 0 then
			killTargets[targetKey] = true;
		end	
	end);
	if table.empty(killTargets) then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'BuffInvoked', { Buff = buff.name });
	AddOvercharge(actions, owner, buff.ApplyAmount, true);
	return unpack(actions);
end
-- 섬광
function Buff_Flash_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	return Result_RemoveBuff(owner, buff.name, true), Result_FireWorldEvent('FlashBuffReleased', {Buff = buff, Level = buff.Lv}, owner, true);
end
-- 연속 공격
function Buff_ContinuousAttack_AbilityUsed(eventArg, buff, owner, giver, ds)
	if buff.DuplicateApplyChecker > 0 or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local masteryTable = GetMastery(owner);
	local actions = {};
	-- 연속 공격
	local notDeadTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local targetKey = GetObjKey(targetInfo.Target);
		if not targetInfo.IsDead then
			notDeadTargets[targetKey] = true;
		else
			notDeadTargets[targetKey] = nil;
		end
	end);
	local hasAnyNotDead = not table.empty(notDeadTargets);
	if hasAnyNotDead then
		local battleEvent = {{Object = owner, EventType = 'BuffInvokedCustomEvent', Args = {Buff = buff.name, EventType = 'FirstHit'}}};
		local config = eventArg.DirectingConfig or {};
		config.NoCamera = true;
		local retAction = Result_UseAbility(owner, eventArg.Ability.name, eventArg.PositionList[#(eventArg.PositionList)], {ReactionAbility = true, BattleEvents = battleEvent}, true, config);
		retAction._ref = eventArg.ActionID;
		retAction._ref_offset = -1;
		if config.Preemptive then
			retAction.nonsequential = true;
		end
		if eventArg.DetailInfo then
			retAction.detail_info = eventArg.DetailInfo;
		end
		retAction.free_action = true;
		buff.DuplicateApplyChecker = buff.DuplicateApplyChecker + 1;
		
		table.insert(actions, retAction);
		InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.Lv, true);
	else
		-- 개량된 연속 공격
		local mastery_ImprovedContinuousAttack = GetMasteryMastered(masteryTable, 'ImprovedContinuousAttack');
		if mastery_ImprovedContinuousAttack then
			MasteryActivatedHelper(ds, mastery_ImprovedContinuousAttack, owner, 'AbilityUsed_Self');
			AddActionRestoreActions(actions, owner);
			-- 버프 소모 처리
			buff.DuplicateApplyChecker = buff.DuplicateApplyChecker + 1;
			InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.Lv, true);
		end
	end
	-- 개량된 주포
	local mastery_EnhancedStrongCannon = GetMasteryMastered(masteryTable, 'EnhancedStrongCannon');
	if mastery_EnhancedStrongCannon and eventArg.Ability.Type == 'Attack' and IsProtocolAbility(eventArg.Ability) then
		local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
			return targetInfo.IsDead;
		end);
		if hasAnyDead then
			MasteryActivatedHelper(ds, mastery_EnhancedStrongCannon, owner, 'AbilityUsed_Self');
			AddAbilityCoolActions(actions, owner, -mastery_EnhancedStrongCannon.ApplyAmount2);
		end
	end	
	return unpack(actions);
end
-- 맹렬한 불꽃
function Buff_BlazingFire_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' or eventArg.Ability.SubType ~= 'Fire' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		if targetInfo.IsDead then
			local target = targetInfo.Target;
			applyTargets[GetObjKey(target)] = target;
		end
		return true;
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	for _, target in pairs(applyTargets) do
		table.append(actions, { Buff_FlameExplosion_Activated(buff, buff.ExplosionType, owner, target) });	
	end
	return unpack(actions);
end
-- 공포의 기운
function Buff_FearAura_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if IsEnemy(owner, target) and targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 then
			applyTargets[GetObjKey(target)] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	for _, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, buff.AddBuff, 1, true);
	end
	return unpack(actions);
end
-- 정보 공유
function Buff_InformationSharing_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit == owner
		or not IsAllyRelation(owner, eventArg.Unit)
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	if not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end	
	local applyTargets = {};
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if info.DefenderState == 'Dodge' or info.DefenderState == 'Block' then
				local objKey = GetObjKey(info.Target);
				applyTargets[objKey] = true;
			end
		end
	end
	return Result_UpdateInstantProperty(owner, buff.name, applyTargets);
end
-- 관리자 권한
function Buff_ManagerAuthority_AbilityUsed(eventArg, buff, owner, giver, ds)
	-- 관리자 권한 프로토콜은 제외
	if not IsProtocolAbility(eventArg.Ability) or eventArg.Ability.name == 'ManagerProtocol' then
		return;
	end
	local actions = {};
	local nextLife = buff.Life - 1;
	if nextLife <= 0 then
		ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
		table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	else
		table.insert(actions, Result_BuffPropertyUpdated('Life', nextLife, owner, buff.name, true, true));
	end
	return unpack(actions);
end
-- 육도윤회
function Buff_SixPathSamsara_AbilityUsed(eventArg, buff, owner, giver, ds)
	-- 육도윤회술은 제외
	if eventArg.Ability.Category ~= 'Ninjutsu' or eventArg.Ability.name == 'SixPathSamsara' then
		return;
	end
	local actions = {};
	local nextLife = buff.Life - 1;
	if nextLife <= 0 then
		ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buff.name });
		table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	else
		table.insert(actions, Result_BuffPropertyUpdated('Life', nextLife, owner, buff.name, true, true));
	end
	return unpack(actions);
end
-- 냉정
function Buff_DeadlyCalm_AbilityUsed(eventArg, buff, owner, giver, ds)
	if not IsGetAbilitySubType(eventArg.Ability, 'ESP') then
		return;
	end
	buff.DuplicateApplyChecker = 1;
end
-- 반항적
function Buff_BeastLoyaltyBad_AbilityUsed(eventArg, buff, owner, giver, ds)
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.AddBuff, 1, true);
	return unpack(actions);
end
-- 독 바르기: 상처감염 독
function Buff_Envenoming_WoundPoison_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsGetAbilitySubType(eventArg.Ability, 'Physical')
		or buff.DuplicateApplyChecker == 0  then
		return;
	end
	local actions = {};
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	-- 버프 레벨 감소
	InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.ApplyAmount, true);
	buff.DuplicateApplyChecker = 0;
	return unpack(actions);
end
-- 독 바르기: XXX
function Buff_Envenoming_Shared_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsGetAbilitySubType(eventArg.Ability, 'Physical')
		or buff.DuplicateApplyChecker == 0  then
		return;
	end
	local actions = {};
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	-- 버프 레벨 감소
	InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.ApplyAmount2, true);
	buff.DuplicateApplyChecker = 0;
	return unpack(actions);
end
-- 은신 
function Buff_Stealth_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Mute then
		return;
	end
	local hasAnyEnemy = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		return IsEnemy(owner, targetInfo.Target);
	end);
	if not hasAnyEnemy then
		return;
	end
	-- 암기 전문가
	local mastery_AmbushNinja = GetMasteryMastered(GetMastery(owner), 'AmbushNinja');
	if mastery_AmbushNinja and eventArg.UserInfo.IsStableAttack and eventArg.Ability.name == 'ThrowDagger' then
		return;
	end
	return Result_RemoveBuff(owner, buff.name, true);
end
-- 신경독
function Buff_Neurotoxin_AbilityUsed(eventArg, buff, owner, giver, ds)
	if owner.TurnState.TurnEnded then
		return;
	end
	local actions = {};
	local addLv = eventArg.UserInfo.UsedActionPoint;
	if addLv > 0 then
		local totalLv = math.min(buff.Lv + addLv, buff:MaxStack(owner));
		if buff.Lv ~= totalLv then
			table.insert(actions, Result_BuffPropertyUpdated('Lv', totalLv, owner, buff.name, false, true, true, true));
		end
	end
	return unpack(actions);
end
-- 불굴의 심장(임시)
function Buff_IndomitableHeart_Temp_AbilityUsed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	return Result_RemoveBuff(owner, buff.name);
end
--------------------------------------------------------------------------------
-- 데미지 줌
----------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 어빌리티 사용 전 [PreAbilityUsing]
----------------------------------------------------------------------------
-- 위력 조절
---@param eventArg preAbilityUsingEventArg
---@param buff buff
---@param owner unit
---@param giver unit
---@param ds any
function Buff_MercyStrike_PreAbilityUsing(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end

	local range = CalculateRange(owner, eventArg.Ability.ApplyRange, eventArg.PositionList[1]);
	local actions = {};
	for _, p in ipairs(range) do
		local u = GetObjectByPosition(GetMission(owner), p);
		if u then
			InsertBuffActions(actions, owner, u, 'MercyStrike_Temp', 1, nil, function(b)
				b.Base_ApplyAmount[1] = buff.ApplyAmount;
			end, true, buff);
		end
	end
	
	return unpack(actions);
end
-- 먹이를 낚음
function Buff_HavingPrey_PreAbilityUsing(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.RemoveBuff.name ~= buff.name then
		return;
	end
		
	local actions = {};
	local buff_HavingPrey = GetBuff(owner, 'HavingPrey');
	local target = GetUnit(GetMission(owner), buff_HavingPrey.ReferenceTarget);
	
	local sp = Result_SetPosition(target, eventArg.PositionList[1]);
	sp.forward = true;
	
	table.insert(actions, sp);
	table.insert(actions, Result_RemoveBuff(target, 'BeingFished'));
	return unpack(actions);
end
-- 경계
function Buff_Overwatching_PreAbilityUsing(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' 
		or eventArg.Ability.RelocatorMoveType == 'Flash'
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	
	local removeBuff = Result_RemoveBuff(owner, 'Overwatching');
	
	local overwatchAbility = FindAbility(owner, owner.OverwatchAbility_Force);
	if overwatchAbility == nil then
		return removeBuff;
	end
	
	local userPos = GetPosition(eventArg.Unit);
	local range = CalculateRange(owner, overwatchAbility.TargetRange, GetPosition(owner));
	local canHit = BuffHelper.IsPositionInRange(userPos, range);
	if not canHit then
		return;
	end	
	
	local battleEvents = {{Object = owner, EventType = 'OverwatchingShot', Args = nil}};
	local abilityAction = Result_UseAbility(owner, overwatchAbility.name, userPos, {ReactionAbility=true, Overwatch=true, BattleEvents = battleEvents}, true, {NoCamera=true});
	abilityAction.free_action = true;
	abilityAction.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, overwatchAbility.TargetRange, GetPosition(owner)), userPos)
	end;
	return removeBuff, abilityAction;
end
-- 제로의 영역
function Buff_Flow_PreAbilityUsing(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' 
		or eventArg.Ability.RelocatorMoveType == 'Flash'
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	return Buff_Flow_PreAbilityUsing_Common(eventArg, buff, owner, giver, ds, owner.OverwatchAbility_Force);
end
function Buff_CrammyVolcano_PreAbilityUsing(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' 
		or eventArg.Ability.RelocatorMoveType == 'Flash'
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	return Buff_Flow_PreAbilityUsing_Common(eventArg, buff, owner, giver, ds, 'Fireball_Vocano');
end
function Buff_Flow_PreAbilityUsing_Common(eventArg, buff, owner, giver, ds, abilityName)
	local alreadyHitSet = GetInstantProperty(owner, 'FlowAlreadyHitSet') or {};
	if alreadyHitSet[GetObjKey(eventArg.Unit)] then
		return;
	end
	
	local overwatchAbility = FindAbility(owner, abilityName);
	if not overwatchAbility then
		return;
	end
	
	local watchingArea = GetInstantProperty(owner, 'FlowWatchingArea');
	if watchingArea == nil then
		return;
	end
	local userPos = GetPosition(eventArg.Unit);
	local canHit = PositionInRange(watchingArea, userPos);
	
	if not canHit then
		return;
	end
	alreadyHitSet[GetObjKey(eventArg.Unit)] = true;
	SetInstantProperty(owner, 'FlowAlreadyHitSet', alreadyHitSet);
	
	local battleEvents = {{Object = owner, EventType = 'BuffInvoked', Args = {Buff = buff.name}}};
	local abilityAction = Result_UseAbility(owner, abilityName, userPos, {Forestallment=true, BattleEvents = battleEvents}, true, {NoCamera=true});
	abilityAction.free_action = true;
	abilityAction.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, overwatchAbility.TargetRange, GetPosition(owner)), userPos)
	end;
	local applyAct = 30;
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
	if action then
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	return abilityAction, action;
end
-- 자동 방어 프로토콜
function Buff_AutoDefence_UnitMoveStarted(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	buff.DuplicateApplyChecker = buff.DuplicateApplyChecker + 1;
end
function Buff_AutoDefence_UnitMoved(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	buff.DuplicateApplyChecker = buff.DuplicateApplyChecker - 1;
end
function Buff_AutoDefence_PreAbilityUsing(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or buff.DuplicateApplyChecker > 0
		or eventArg.Ability.Type ~= 'Attack' 
		or eventArg.Ability.RelocatorMoveType == 'Flash'
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	local overwatchAbility = FindAbility(owner, owner.OverwatchAbility);
	if not overwatchAbility then
		return;
	end
	local target = eventArg.Unit;
	local targetPos = GetPosition(target);
	local usingPos = eventArg.PositionList[1];
	local applyArea = CalculateRange(target, eventArg.Ability.ApplyRange, usingPos);
	local ownerPos = GetPosition(owner);
	
	local canHit = PositionInRange(applyArea, ownerPos);
	if not canHit then
		return;
	end
	
	local overwatchArea = CalculateRange(owner, overwatchAbility.TargetRange, ownerPos);
	local canOverwatch = PositionInRange(overwatchArea, targetPos);
	if not canOverwatch then
		return;
	end
	
	local battleEvents = {{Object = owner, EventType = 'BuffInvokedCustomEvent', Args = {Buff = buff.name, EventType = 'Beginning'}}};
	local abilityAction = Result_UseAbilityTarget(owner, overwatchAbility.name, target, {ReactionAbility=true, BattleEvents = battleEvents}, true, {NoCamera=true});
	abilityAction.free_action = true;
	abilityAction.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, overwatchAbility.TargetRange, GetPosition(owner)), targetPos)
	end;
	buff.DuplicateApplyChecker = buff.DuplicateApplyChecker + 1;	
	ds:WorldAction(abilityAction, true);
	buff.DuplicateApplyChecker = buff.DuplicateApplyChecker - 1;
end
----------------------------------------------------------------------------
-- 어빌리티에 영향을 받음 [AbilityAffected]
----------------------------------------------------------------------------
-- 위력 조절 기능용
function Buff_MercyStrike_Temp_AbilityAffected(eventArg, buff, owner, giver, ds)
	return Result_RemoveBuff(owner, buff.name);
end
-- 불꽃 갈기
function Buff_ReflectDamage_AbilityAffected(eventArg, buff, owner, giver, ds)
	if not IsEnemy(owner, eventArg.User)
		or GetDistanceFromObjectToObject(owner, eventArg.User) > 1.8 then
		return;
	end
	
	local damageTotal = 0;
	ForeachAbilityUsingInfo(eventArg.AbilityTargetInfos, function(targetInfo)
		if targetInfo.MainDamage > 0 then
			damageTotal = damageTotal + targetInfo.MainDamage;
		end
	end);
	
	if damageTotal <= 0 then
		return;
	end
	
	local ratio = buff.ReflectDamageRatio;
	if #GetBuffType(eventArg.User, 'Debuff', nil, buff.ReflectDamageAdditionalBuffGroup) > 0 then
		ratio = ratio * buff.ReflectDamageAdditionalRatio;
	end
	
	local applyDamage = damageTotal * (ratio / 100);
	
	local actions = {};
	local realDamage, reasons = ApplyDamageTest(eventArg.User, applyDamage, 'Fixed');
	ReasonToUpdateBattleEventMulti(eventArg.User, ds, reasons);
	DirectDamageByType(ds, eventArg.User, buff.name, applyDamage, eventArg.User.HP - realDamage, false, eventArg.User.HP == realDamage);
	table.insert(actions, Result_Damage(applyDamage, 'Normal', 'Hit', owner, eventArg.User, 'Fixed', buff.ReflectDamageType, buff));
	AddBuffDamageChat(ds, eventArg.User, buff, realDamage);
	return unpack(actions);
end
-- 길들이기
function Buff_Taming_AbilityAffected(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'TamingTarget');
	local tamingTarget = GetUnit(owner, targetKey);
	if tamingTarget == nil then
		return;
	end
	local movePos = GetPosition(tamingTarget);
	if IsInSight(owner, movePos, true) then
		local objKey = GetObjKey(owner);
		ds:ReleasePose(objKey, 'None');
		ds:LookAt(objKey, targetKey, true);
		ds:PlayPose(objKey, 'TameStart', 'TameStd', false, 'TameStdIdle', true);
		return;
	end
	local target = nil;
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	return Result_FireWorldEvent('TamingFailed', {Unit=owner, Target=target}, nil, true);
end
-- 교감
function Buff_Communicating_AbilityAffected(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'CommunicatingTarget');
	local tamingTarget = GetUnit(owner, targetKey);
	if tamingTarget == nil then
		return;
	end
	local movePos = GetPosition(tamingTarget);
	if IsInSight(owner, movePos, true) then
		local objKey = GetObjKey(owner);
		ds:ReleasePose(objKey, 'None');
		ds:LookAt(objKey, targetKey, true);
		ds:PlayPose(objKey, 'TameStart', 'TameStd', false, 'TameStdIdle', true);
		return;
	end
	local target = nil;
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	return Result_FireWorldEvent('CommunicatingFailed', {Unit=owner, Target=target}, nil, true);
end
function Buff_Occupying_AbilityAffected(eventArg, buff, owner, giver, ds)
	local targetKey = GetInstantProperty(owner, 'InteractionTarget');
	local objKey = GetObjKey(owner);
	ds:ReleasePose(objKey, 'None');
	ds:LookAt(objKey, targetKey, true);
	ds:PlayPose(objKey, 'InteractionStart', 'InteractionStd', false, 'InteractionStdIdle', true);
end
-- 화합물 만들기
function Buff_MakeConcoction_AbilityAffected(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or GetExpTaker(eventArg.User) == owner then	-- 자기꺼 터진걸로는 증가안함
		return;
	end
	
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.AddBuff, #eventArg.AbilityTargetInfos, true);
	return unpack(actions);
end
-- 영리한 티마
function Buff_Tima_CheckMode_AbilityAffected(eventArg, buff, owner, giver, ds)
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
	local applyAct = -buff.ApplyAmount;

	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly', nil, eventArg.Ability);
	ds:UpdateBattleEvent(objKey, 'BuffInvoked', { Buff = buff.name });
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	AddBuffEventChat(ds, owner, buff);
	
	return unpack(actions);
end
-- 공포의 기운
function Buff_FearAura_AbilityAffected(eventArg, buff, owner, giver, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyDodgeOrBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge' or targetInfo.DefenderState == 'Block';
	end);
	if not hasAnyDodgeOrBlock then
		return;
	end
	local actions = {};
	local target = eventArg.User;
	InsertBuffActions(actions, owner, target, buff.AddBuff, 1, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', { Buff = buff.name });
	return unpack(actions);
end
-- 정보 변조
function Buff_InformationFalsification_AbilityAffected(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	if not IsEnemy(owner, eventArg.User) or eventArg.User.HP <= 0 then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	return Result_UpdateInstantProperty(owner, buff.name, eventArg.Ability.SubType);
end
-- 설산의 찬바람
function Buff_CrammyBlizzard_AbilityAffected(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	if not IsEnemy(owner, eventArg.User) or eventArg.User.HP <= 0 then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local actions = {};
	local target = eventArg.User;
	local targetKey = GetObjKey(target);
	local ownerKey = GetObjKey(owner);
	
	local cam = ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false);
	ds:UpdateBattleEvent(ownerKey, 'BuffInvoked', { Buff = buff.name });
	local f = ds:ForceEffect(ownerKey, '_CENTER_', targetKey, '_CENTER_', 'IceArrow');	
	InsertBuffActions(actions, owner, target, buff.AddBuff, 1);
	for _, action in ipairs(actions) do
		action._ref = f;
		action._ref_offset = -1;
	end
	return unpack(actions);
end
-- 그림자 환영
function Buff_ShdowIllusion_AbilityAffected(eventArg, buff, owner, giver, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyFlag = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return SafeIndex(targetInfo.DamageFlag, 'ShdowIllusion');
	end);
	if not hasAnyFlag then
		return;
	end
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 팀 변경 [UnitTeamChanged]
----------------------------------------------------------------------------
function Buff_UnderControl_UnitTeamChanged(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= giver then
		return;
	end
	return Result_ChangeTeam(owner, eventArg.Team);
end
function Buff_CommonAura_UnitTeamChanged_InRange(eventArg, buff, owner, giver, ds)
	if (eventArg.Unit ~= owner and eventArg.Unit.Untargetable) and not buff.AuraAllowUntargetable then
		return;
	end
	
	local myChange = eventArg.Unit == owner;
	local enterMyTeam = BuffHelper.IsRelationMatched(GetRelationByTeamName(GetMission(owner), GetTeam(owner), eventArg.Team), buff.AuraRelation);
	local leaveMyTeam = BuffHelper.IsRelationMatched(GetRelationByTeamName(GetMission(owner), GetTeam(owner), eventArg.PrevTeam), buff.AuraRelation);
	if not myChange 
		and not enterMyTeam
		and not leaveMyTeam then
		return;
	end

	local targetArgs = {};
	local ownerPos = GetPosition(owner);

	if myChange then
		local rangeObjects = {};
		
		-- 이전에 오라 걸려있던 오브젝트들을 기록
		local prevObjects = BuffHelper.GetAuraTargets(owner, buff.name);

		for _, obj in ipairs(prevObjects) do
			if obj ~= owner then
				local unitKey = GetObjKey(obj);
				if rangeObjects[unitKey] == nil then
					rangeObjects[unitKey] = { object = obj, endInRange = false };
				end
				rangeObjects[unitKey].prevInRange = true;
			end
		end
		
		-- 새 팀에서 범위 내에 있는 오브젝트들을 기록
		local endRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
		local endObjects = BuffHelper.GetObjectsInRange(GetMission(owner), endRange, nil, buff.AuraAllowNonOccupyTarget, buff.AuraAllowUntargetable);

		for _, obj in ipairs(endObjects) do
			if obj ~= owner and BuffHelper.IsRelation(owner, obj, buff.AuraRelation) then
				local unitKey = GetObjKey(obj);
				if rangeObjects[unitKey] == nil then
					rangeObjects[unitKey] = { object = obj, prevInRange = false };
				end
				rangeObjects[unitKey].endInRange = true;
			end
		end
	
		-- 탐색된 오브젝트 정보들을 가지고 버프가 변경되어야 하는 대상들을 추출
		for unitKey, info in pairs(rangeObjects) do
			if info.prevInRange and (not info.endInRange) then
				table.insert(targetArgs, { targetUnit = info.object, buffLevel = -buff.Lv, moveUnit = nil, checkPos = nil, checkRange = nil });
			elseif (not info.prevInRange) and info.endInRange then
				table.insert(targetArgs, { targetUnit = info.object, buffLevel = buff.Lv, moveUnit = nil, checkPos = nil, checkRange = nil });
			end
		end
	else
		local prevInRange = BuffHelper.IsAuraTarget(owner, buff.name, eventArg.Unit);
		
		local applyRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
		local endInRange = BuffHelper.IsPositionInRange(GetPosition(eventArg.Unit), applyRange);
		if not enterMyTeam then
			endInRange = false;
		end
		
		if prevInRange and (not endInRange) then
			table.insert(targetArgs, { targetUnit = eventArg.Unit, buffLevel = -buff.Lv, moveUnit = nil, checkPos = nil, checkRange = nil });
		elseif (not prevInRange) and endInRange then
			table.insert(targetArgs, { targetUnit = eventArg.Unit, buffLevel = buff.Lv, moveUnit = nil, checkPos = nil, checkRange = nil });		
		end
	end
	
	Buff_CommonAura_ApplyBuffToTargets(ds, targetArgs, giver, owner, buff.name, buff.AuraBuff);
end
-- 주시
function Buff_BeholderVision_UnitTeamChanged(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= giver then
		return;
	end
	return Result_SightSharing(owner, eventArg.PrevTeam, false, true), Result_SightSharing(owner, eventArg.Team, true, true);
end
-- 야수 소환/기계 소환
function Buff_Subordinate_UnitTeamChanged(eventArg, buff, owner, giver, ds)
	-- 소환자의 팀 변경을 따라간다
	local masterKey = GetInstantProperty(owner, 'SummonMaster');
	if GetObjKey(eventArg.Unit) ~= masterKey then
		return;
	end
	-- Brainwashing 상태이면, 해당 기능에 의한 팀 변경을 우선함
	if GetBuffStatus(owner, 'Brainwashing', 'Or') then
		return;
	end
	return Result_ChangeTeam(owner, eventArg.Team, eventArg.Temporary);
end
-------------------------------------------------------------------------------
-- 버프 프로퍼티 갱신 [BuffPropertyUpdated]
-------------------------------------------------------------------------------
function Buff_UnstableConcoction_BuffPropertyUpdated(eventArg, buff, owner, giver, ds)
	if buff ~= eventArg.Buff 
		or eventArg.PropertyName ~= 'Lv' then
		return;
	end
	if buff.Lv < buff:MaxStack(owner) then
		ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', {Buff = buff.name});
		return;
	end
	
	return Result_FireWorldEvent('ConcoctionFlooded', {}, owner, true);
end
-------------------------------------------------------------------------------
-- 유닛 프로퍼티 갱신 [UnitPropertyUpdated]
-------------------------------------------------------------------------------
-- 과부하
---@param eventArg unitPropertyUpdatedEventArg
---@param buff buff
---@param owner unit
---@param giver unit
---@param ds DirectingScripter
function Buff_SecondWind_MindAndBody_PropertyUpdated(eventArg, buff, owner, giver, ds)
	if eventArg.PropertyName ~= 'Overload'
		or HasBuff(owner, 'Exhaustion')
		or owner.Overload < 500 then
		return;
	end

	local actions = {};
	InsertBuffActions(actions, owner, owner, 'Exhaustion', 1, true);
	return unpack(actions);
end
function Buff_Taming_UnitPropertyUpdated(eventArg, buff, owner, giver, ds)
	if eventArg.PropertyName ~= 'Act' then
		return;
	end
	local tamingTime = GetInstantProperty(owner, 'TamingTime');
	if tamingTime == nil then
		return;
	end	
	local newAct = tonumber(eventArg.Value);
	if tamingTime == newAct then
		return;
	end
	local target = nil;
	local targetKey = GetInstantProperty(owner, 'TamingTarget');
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	return Result_FireWorldEvent('TamingFailed', {Unit=owner, Target=target});
end
function Buff_Communicating_UnitPropertyUpdated(eventArg, buff, owner, giver, ds)
	if eventArg.PropertyName ~= 'Act' then
		return;
	end
	local tamingTime = GetInstantProperty(owner, 'CommunicatingTime');
	if tamingTime == nil then
		return;
	end	
	local newAct = tonumber(eventArg.Value);
	if tamingTime == newAct then
		return;
	end
	local target = nil;
	local targetKey = GetInstantProperty(owner, 'CommunicatingTarget');
	if targetKey then
		local mission = GetMission(owner);
		target = GetUnit(mission, targetKey);
	end
	return Result_FireWorldEvent('CommunicatingFailed', {Unit=owner, Target=target});
end
-------------------------------------------------------------------------------
-- 시간 진행 [TimeElapsed]
-------------------------------------------------------------------------------
function Buff_Taming_TimeElapsed(eventArg, buff, owner, giver, ds)
	local tamingTime = GetInstantProperty(owner, 'TamingTime');
	if tamingTime == nil then
		return;
	end	
	tamingTime = tamingTime - eventArg.ElapsedTime;
	if tamingTime > 0 then
		SetInstantProperty(owner, 'TamingTime', tamingTime);
		return;
	end
	
	local mission = GetMission(owner);
	local targetKey = GetInstantProperty(owner, 'TamingTarget');
	local target = GetUnit(mission, targetKey);
	
	SetInstantProperty(owner, 'TamingTarget', nil);
	SetInstantProperty(owner, 'TamingTime', nil);
	
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name));
	ApplyTamingActions(actions, owner, target);
	table.insert(actions, Result_FireWorldEvent('TamingSucceeded', {Unit=owner, Target=target}));
	return unpack(actions);
end
function Buff_Communicating_TimeElapsed(eventArg, buff, owner, giver, ds)
	local tamingTime = GetInstantProperty(owner, 'CommunicatingTime');
	if tamingTime == nil then
		return;
	end	
	tamingTime = tamingTime - eventArg.ElapsedTime;
	if tamingTime > 0 then
		SetInstantProperty(owner, 'CommunicatingTime', tamingTime);
		return;
	end
	
	local mission = GetMission(owner);
	local targetKey = GetInstantProperty(owner, 'CommunicatingTarget');
	local target = GetUnit(mission, targetKey);
	
	SetInstantProperty(owner, 'CommunicatingTarget', nil);
	SetInstantProperty(owner, 'CommunicatingTime', nil);

	buff.DuplicateApplyChecker = 1;
	
	local actions = {};
	ApplyCommunicatingActions(actions, owner, target, ds);
	table.insert(actions, Result_RemoveBuff(owner, buff.name));
	table.insert(actions, Result_FireWorldEvent('CommunicatingSucceeded', {Unit=owner, Target=target}));
	return unpack(actions);
end
function Buff_Occupying_TimeElapsed(eventArg, buff, owner, giver, ds)
	local occupyingTime = GetInstantProperty(owner, 'InteractionTime');
	if occupyingTime == nil then
		return;
	end	
	occupyingTime = occupyingTime - eventArg.ElapsedTime;
	if occupyingTime > 0 then
		SetInstantProperty(owner, 'InteractionTime', occupyingTime);
		return;
	end
	
	local mission = GetMission(owner);
	local targetKey = GetInstantProperty(owner, 'InteractionTarget');
	local target = GetUnit(mission, targetKey);
	
	SetInstantProperty(owner, 'InteractionTarget', nil);
	SetInstantProperty(owner, 'InteractionTime', nil);

	buff.DuplicateApplyChecker = 1;
	
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name));
	ds:ReleasePose(GetObjKey(owner), 'OccupyingEnd');
	table.insert(actions, Result_UpdateInteraction(target, 'Occupy', true));
	table.insert(actions, Result_Interaction(owner, target, 'Occupy', FindAbility(owner, 'Occupy')));
	return unpack(actions);
end
function Buff_RepairInteraction_TimeElapsed(eventArg, buff, owner, giver, ds)
	local repairTime = GetInstantProperty(owner, 'RepairTime');
	if repairTime == nil then
		return;
	end	
	repairTime = repairTime - eventArg.ElapsedTime;
	if repairTime > 0 then
		SetInstantProperty(owner, 'RepairTime', repairTime);
		return;
	end
	
	local mission = GetMission(owner);
	local targetKey = GetInstantProperty(owner, 'RepairTarget');
	local target = GetUnit(mission, targetKey);
	
	SetInstantProperty(owner, 'RepairTarget', nil);
	SetInstantProperty(owner, 'RepairTime', nil);
	
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	table.insert(actions, Result_Interaction(owner, target, 'Repair', GetAbilityObject(owner, 'Repair')));
	if owner.Act > 0 then
		table.insert(actions, Result_PropertyUpdated('Act', 0, owner, true, true));
	end
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- [MissionEnd] 미션 종료
----------------------------------------------------------------------------
-- 제어권 탈취
function Buff_ControlTakeover_MissionEnd(eventArg, buff, owner, giver, ds)
	if eventArg.Winner ~= 'player' then
		return;
	end
	
	local monsterType = GetInstantProperty(owner, 'MonsterType');
	if monsterType == nil then
		return;
	end
	
	local monsterList = GetClassList('Monster');
	local itemList = GetClassList('Item');
	local itemDropList = SafeIndex(monsterList[monsterType], 'Rewards');
	if itemDropList == nil then
		return;
	end
	
	local actions = {};
	for index, value in ipairs (itemDropList) do
		local item = itemList[value.Item];
		if item ~= nil then
			local rmin, rmax = math.min(value.Min, value.Max), math.max(value.Min, value.Max);
			local itemCount = math.random(rmin, rmax);
			table.insert(actions, Result_GiveItem(giver, value.Item, itemCount));
		end
	end
	-- 도감 경험치 증가.
	AddExp_TroubleMaker(GetMissionDatabaseCommiter(GetMission(owner)), owner, giver, 'Normal', false, false, ds);
	
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 액션 구분자 [ActionDelimiter]
----------------------------------------------------------------------------
-- 위력조절 기능용 임시 버프
function Buff_MercyStrike_Temp_ActionDelimiter(eventArg, buff, owner, giver, ds)
	return Result_RemoveBuff(owner, buff.name);
end
--------------------------------------------------------------------------------
-- 지형 효과 [FieldEffectAdded, FieldEffectRemoved]
----------------------------------------------------------------------------
-- 거미줄 타기
function Buff_ClimbWeb_FieldEffectRemoved(eventArg, buff, owner, giver, ds)
	if eventArg.FieldEffectType ~= 'Web' then
		return;
	end
	local objPos = GetPosition(owner);
	if not BuffHelper.IsPositionInRange(objPos, eventArg.PositionList) then
		return;
	end
	local actions = {};
	-- 버프 삭제 (턴이 남아있으므로, 버프 삭제에서 자동으로 FallWeb이 써지지 않음)
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	-- 수동으로 FallWeb_Move 어빌리티 사용
	local ability_FallWeb = GetAbilityObject(owner, 'FallWeb_Move');
	if not ability_FallWeb then
		LogAndPrint('[DataError]', 'No Ability for fall - owner:', GetUnitDebugName(owner));
		return;
	end
	local mission = GetMission(owner);
	local ownerPos = GetPosition(owner);
	local range = CalculateRange(owner, ability_FallWeb.TargetRange, ownerPos);
	local candidate = table.filter(range, function(pos)
		local obj = GetObjectByPosition(mission, pos);
		return (not obj) or (obj == owner);
	end);
	candidate = table.shuffle(candidate);
	table.sort(candidate, function(lhs, rhs)
		return GetDistance3D(lhs, ownerPos) < GetDistance3D(rhs, ownerPos);
	end);
	local targetPos = (#candidate > 0) and candidate[1] or ownerPos;
	table.insert(actions, Result_UseAbility(owner, ability_FallWeb.name, targetPos, {}, true));
	-- 낙하 지점에 거미줄이 없으면 기절 추가
	local fieldEffects = GetFieldEffectByPosition(mission, targetPos);
	local isWeb = table.exist(fieldEffects, function(instance) return instance.Owner.name == 'Web' end);
	if not isWeb then
		InsertBuffActions(actions, owner, owner, 'Stun', 1, true);
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 기타 이벤트
----------------------------------------------------------------------------
--- UnitArrivedEscapeArea
function Direct_RescueUnrestCitizen(mid, ds, args)
	local owner = args.Owner;
	
	local unitKey = GetObjKey(owner);
	ds:HideBattleStatus(unitKey);
	
	local moveTo = GetMovePosition(owner, args.ExitPos, 0);
	local playSoundID = ds:PlaySound('Success.wav', 'Layout', 1);
	local sleepID = ds:Sleep(3);	

	local messageID = ds:UpdateInteractionMessage(unitKey, 'Rescue', owner.Info.name);
	ds:Connect(playSoundID, messageID, 0.5);
	ds:Connect(sleepID, messageID, 0);	
	ds:UpdateBalloonCivilMessage(unitKey, 'Rescued', owner.Info.AgeType);
	ds:Sleep(1.5);
	ds:Move(GetObjKey(owner), moveTo, false, false);
	
	local invalidPos = InvalidPosition();
	local moveId = ds:Move(GetObjKey(owner), invalidPos, true, true, '', 0, 0, false, 1, true, nil, nil, true);
	local moveAction = Result_SetPosition(owner, invalidPos);
	moveAction._ref = moveId;
	moveAction._ref_offset = 0;
	ds:WorldAction(moveAction, true);
	
	return Result_DestroyObject(owner, false, true);
end
function Buff_Unrest_UnitArrivedEscapeArea(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	local company = GetCompanyByTeam(GetMission(owner), GetTeam(owner));
	if company then
		AddCompanyStats(company, 'Rescue', 1);
	end
	
	local exitPosO = eventArg.Dashboard.ExitPos;
	local exitPos = {x = exitPosO.x, y = exitPosO.y, z = exitPosO.z};
	if IsInvalidPosition(exitPos) then
		exitPos = FindAIMovePosition(owner, {FindMoveAbility(owner)}, function (self, adb)
			return adb.MoveDistance;	-- 가장 멀리 갈 수 있는 아무데나
		end, {}, {});
	end
	
	local setPos = Result_SetPosition(owner, InvalidPosition());
	setPos.sequential = true;
	setPos.forward = true;
	
	return Result_FireWorldEvent('CitizenRescuing', {Unit=owner, Company=company}), Result_DirectingScript('Direct_RescueUnrestCitizen', {Owner = owner, ExitPos = exitPos}), Result_FireWorldEvent('CitizenRescued', {Unit=owner, Company=company});
end
function Direct_FakeRescueRevealedEscape(mid, ds, args)
	local owner = args.Owner;
	local exitPos = args.ExitPos;
	
	local unitKey = GetObjKey(owner);
	local moveTo = GetMovePosition(owner, exitPos, 0);
	local playSoundID = ds:PlaySound('Success.wav', 'Layout', 1);
	local messageID = ds:UpdateInteractionMessage(unitKey, 'Rescue', owner.Info.name);
	local sleepID = ds:Sleep(3);
	ds:Connect(playSoundID, messageID, 0.5);
	ds:Connect(sleepID, messageID, 0);
	
	ds:UpdateBalloonCivilMessage(unitKey, 'FakeRescued', owner.Info.AgeType);
	ds:Sleep(1.5);
	ds:Move(GetObjKey(owner), moveTo, false, false);	
	
	local invalidPos = InvalidPosition();
	local moveId = ds:Move(GetObjKey(owner), invalidPos, true, true, '', 0, 0, false, 1, true, nil, nil, true);
	local moveAction = Result_SetPosition(owner, invalidPos);
	moveAction._ref = moveId;
	moveAction._ref_offset = 0;
	ds:WorldAction(moveAction, true);
	
	return Result_DestroyObject(owner, false, true);
end
function Buff_FakeRescueRevealed_UnitArrivedEscapeArea(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	local company = GetCompanyByTeam(GetMission(owner), GetTeam(owner));
	if company then
		AddCompanyStats(company, 'Rescue', 1);
	end
	
	local exitPosO = eventArg.Dashboard.ExitPos;
	local exitPos = {x = exitPosO.x, y = exitPosO.y, z = exitPosO.z};
	
	return Result_FireWorldEvent('CitizenRescuing', {Unit=owner}), Result_DirectingScript('Direct_FakeRescueRevealedEscape', {Owner = owner, ExitPos = exitPos}), Result_FireWorldEvent('CitizenRescued', {Unit=owner});
end
function Buff_CarryingBodies_UnitArrivedEscapeArea(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local target = GetInstantProperty(owner, buff);
	return Result_FireWorldEvent('UnitArrivedEscapeArea', {Unit = target, Dashboard = eventArg.Dashboard});
end
--- UnitDetected
function Buff_Trick_UnitDetected(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	
	return Result_RemoveBuff(owner, buff.name);
end
--- HackingOccured
function Buff_Detecting_HackingOccured(eventArg, buff, owner, giver, ds, remote)
	if eventArg.Success then
		local objKey = GetObjKey(owner);
		local pos = GetPosition(owner);
		local messageID = ds:UpdateInteractionMessage(objKey, 'Hacked', owner.Info.name);		
		local changeAniID = ds:PlayPose(objKey, 'AstdIdle', '', true);
		local camID = ds:ChangeCameraPosition(pos.x, pos.y, pos.z, false, 1);
		local sightObjKey = objKey..'_TempSight';
		local destroySightID = ds:DestroyClientSightObject(sightObjKey);
		local createSightID = ds:CreateClientSightObject(sightObjKey, pos.x, pos.y, pos.z, owner.SightRange);
		local sleepID = ds:Sleep(1.5);
		
		
		local particleID = ds:PlayParticle(objKey, '_TOP_', 'Particles/Dandylion/ControlAcquired', 1);
				
		ds:Connect(createSightID, camID, 0);
		ds:Connect(particleID, camID, 0.5);
		ds:Connect(messageID, camID, -1);
		ds:Connect(changeAniID, camID, -1);
		ds:Connect(sleepID, camID, -1);	
		ds:Connect(destroySightID, sleepID, 3);
		ReplaceWatchtower(owner, 'Active', GetTeam(eventArg.Hacker), ds, sleepID);
		ds:Sleep(1.5);
	else
		ds:WorldAction(Result_FireWorldEvent('UnitDetected', {Unit=eventArg.Hacker}, eventArg.Hacker));
		if remote then
			return Buff_Patrol_Wakeup_Process(owner, eventArg.Hacker, ds, false, nil, 'SupportCall', nil, 'Patrol', false);	
		else
			return Buff_Patrol_FindEnemy(owner, eventArg.Hacker, nil, ds, false, nil, true, 'Patrol');
		end
	end
end
function Buff_Dormant_HackingOccured(eventArg, buff, owner, giver, ds, remote)
	if eventArg.Success then
		ReplaceWatchtower(owner, 'Active', GetTeam(eventArg.Hacker), ds);
	else
		local mission = GetMission(owner);
		local newObjKey, actions = ReplaceWatchtower(owner, 'Active', GetTeam(owner));
		for _, action in ipairs(actions) do
			ds:WorldAction(action);
		end
		ds:WorldAction(Result_FireWorldEvent('UnitDetected', {Unit=eventArg.Hacker}, eventArg.Hacker));
		local newTower = GetUnit(mission, newObjKey);
		if remote then
			return Buff_Patrol_Wakeup_Process(newTower, eventArg.Hacker, ds, false, nil, 'SupportCall', nil, 'Patrol', false);
		else
			return Buff_Patrol_FindEnemy(newTower, eventArg.Hacker, GetPosition(eventArg.Hacker), ds, false, nil, nil, 'Patrol');
		end
	end
end
-- Deactivated
function Buff_DetectingWatchtower_Deactivated(eventArg, buff, owner, giver, ds)
	ReplaceWatchtower(owner, 'Deactive', GetTeam(owner), ds, nil);
end
-- Activated
function Buff_Dormant_Activated(eventArg, buff, owner, giver, ds)
	ReplaceWatchtower(owner, 'Active', GetTeam(owner), ds, nil);
end
-- WatchtowerControl
function Buff_DetectingWatchtower_WatchtowerControl(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Commander) ~= 'Team' then
		return;
	end
	
	local command = eventArg.Command;

	if command == 'Activate' then
		-- 이미 활성화.
	elseif command == 'Deactivate' then
		return Buff_DetectingWatchtower_Deactivated({Unit=eventArg.Commander}, buff, owner, giver, ds);
	elseif command == 'Converted' or command == 'Alert' then
		return Buff_Dormant_HackingOccured({Success = command == 'Converted', Hacker = eventArg.Hacker}, buff, owner, giver, ds, true);
	end
end
function Buff_Dormant_WatchtowerControl(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Commander) ~= 'Team' then
		return;
	end
	
	local command = eventArg.Command;
	if command == 'Activate' then
		return Buff_Dormant_Activated({Unit=eventArg.Commander}, buff, owner, giver, ds);
	elseif command == 'Deactivate' then
		-- 이미 비활성화
	elseif command == 'Converted' or command == 'Alert' then
		return Buff_Dormant_HackingOccured({Success = command == 'Converted', Hacker = eventArg.Hacker}, buff, owner, giver, ds, true);
	end
end
-- Stand
function Buff_Patrol_Search(eventArg, buff, owner, giver, ds)
	if GetBuff(owner, 'Silence') then
		return;
	end
	local isFindEnemy = false;
	local findObj = nil;
	local mission = GetMission(owner);
	local unitsInSight = nil;
	if eventArg.FullSightSearch then
		unitsInSight = GetAllUnitInSight(owner, true, owner.SightRange - buff.SightRange);
	else
		unitsInSight = GetAllUnitInSight(owner, true);
	end
	for j, unit in ipairs(unitsInSight) do
		local unitPos = GetPosition(unit);
		if (function()
			if unit == owner or unit.Mute then
				return false;
			end
			local rel = GetRelation(owner, unit);
			return rel == 'Enemy';
		end)() then
			isFindEnemy = true;
			findObj = unit;
			break;
		end
	end
	
	if not isFindEnemy then
		return;
	end
	
	SetInstantProperty(owner, 'PatrolEnemyPosition', GetPosition(findObj));

	return Buff_Patrol_FindEnemy(owner, findObj, GetPosition(findObj), ds, false, eventArg.MoveID, nil, 'Patrol', true);
end
-- ConcoctionFlooded
function Buff_UnstableConcoction_ConcoctionFlooded(eventArg, buff, owner, giver, ds)
	ds:UpdateAchievement('SituationUnstableConcoction', true, GetTeam(owner));
	return Result_RemoveBuff(owner, buff.name, true), Buff_FlameExplosion_Activated(buff, buff.ExplosionType, owner, owner, ds);
end
-- TamingFailed
function Buff_Taming_TamingFailed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local mission = GetMission(owner);
	local targetKey = GetInstantProperty(owner, 'TamingTarget');
	local target = GetUnit(mission, targetKey);

	local actions = {};
	ApplyTamingFailedActions(actions, owner, target, ds);
	return unpack(actions);
end
function ApplyTamingFailedActions(actions, owner, target, ds)
	local ownerKey = GetObjKey(owner);
	local targetKey = GetObjKey(target);
	
	SetInstantProperty(owner, 'TamingTarget', nil);
	SetInstantProperty(owner, 'TamingTime', nil);
	
	if target and not IsDead(target) then
		ds:EnableTemporalSightTarget(targetKey, 0, 1);
		ds:ChangeCameraTarget(targetKey, '_SYSTEM_', false, false);
		ds:PlayAni(targetKey, 'Rage', false);
		InsertBuffActions(actions, owner, target, 'Rage', 1, true);
		if not IsDead(owner) then
			InsertBuffActions(actions, owner, target, 'Provocation', 1, true, function(buff)
				buff.ReferenceTarget = GetObjKey(owner)
			end);
		else
			table.insert(actions, Result_RemoveBuff(target, 'Provocation', true));
		end
		ds:DisableTemporalSightTarget(targetKey, 0);
	end
	
	if not IsDead(owner) then
		ds:ReleasePose(ownerKey, 'None');
		ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false);
		ds:UpdateBattleEvent(ownerKey, 'TamingFailed', {});
	end
	
	table.insert(actions, Result_RemoveBuff(owner, 'Taming', true));
	table.insert(actions, Result_PropertyUpdated('Act', 0, owner, true, true));
	table.insert(actions, Result_UpdateInstantProperty(target, 'TamingUnit', nil));
end
function Buff_Communicating_CommunicatingFailed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner
		or buff.DuplicateApplyChecker > 0 then		-- 이미 성공처리 지나감
		return;
	end
	local mission = GetMission(owner);
	local targetKey = GetInstantProperty(owner, 'CommunicatingTarget');
	local target = GetUnit(mission, targetKey);

	local actions = {};
	ApplyCommunicatingFailedActions(actions, owner, target, ds);
	return unpack(actions);
end
function ApplyCommunicatingFailedActions(actions, owner, target, ds)
	local ownerKey = GetObjKey(owner);
	local targetKey = GetObjKey(target);
	
	SetInstantProperty(owner, 'CommunicatingTarget', nil);
	SetInstantProperty(owner, 'CommunicatingTime', nil);
	
	if target and not IsDead(target) then
		ds:EnableTemporalSightTarget(targetKey, 0, 1);
		ds:ChangeCameraTarget(targetKey, '_SYSTEM_', false, false);
		ds:PlayAni(targetKey, 'Rage', false);
		InsertBuffActions(actions, owner, target, 'Rage', 1, true);
		if not IsDead(owner) then
			InsertBuffActions(actions, owner, target, 'Provocation', 1, true, function(buff)
				buff.ReferenceTarget = GetObjKey(owner)
			end);
		else
			table.insert(actions, Result_RemoveBuff(target, 'Provocation', true));
		end
		ds:DisableTemporalSightTarget(targetKey, 0);
	end
	
	if not IsDead(owner) then
		ds:ReleasePose(ownerKey, 'None');
		ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false);
		ds:UpdateBattleEvent(ownerKey, 'CommunicatingFailed', {});
	end
	
	table.insert(actions, Result_RemoveBuff(owner, 'Communicating', true));
	table.insert(actions, Result_PropertyUpdated('Act', 0, owner, true, true));
	table.insert(actions, Result_UpdateInstantProperty(target, 'CommunicatingUnit', nil));
end
function Buff_Occupying_OccupyingFailed(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner
		or buff.DuplicateApplyChecker > 0 then		-- 이미 성공처리 지나감
		return;
	end
	local interactionTarget = GetUnit(GetMission(owner), GetInstantProperty(owner, 'InteractionTarget'), nil);
	SetInstantProperty(owner, 'InteractionTarget', nil);
	SetInstantProperty(owner, 'InteractionTime', nil);

	if not IsDead(owner) then
		local ownerKey = GetObjKey(owner);
		ds:ReleasePose(ownerKey, 'None');
		ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false);
		ds:UpdateBattleEvent(ownerKey, 'OccupyingFailed', {});
	end
	
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, 'Occupying', true));
	table.insert(actions, Result_PropertyUpdated('Act', 0, owner, true, true));
	table.insert(actions, Result_UpdateInteraction(interactionTarget, 'Occupy', true));
	return unpack(actions);
end
-- BloodyWitchApplied
function Buff_OriginOfLife_BloodWitchApplied(eventArg, buff, owner, giver, ds)
	local targetArgs = {};
	
	local targetRange = BuffHelper.CalculateRangeAroundObject(owner, buff.AuraRange);
	local targetObjects = BuffHelper.GetObjectsInRange(GetMission(owner), targetRange);
	
	
	local addHP = eventArg.RestoreHPAmount;
	local buff = eventArg.Buff;
	local connectID = ds:Sleep(0);
	
	local actions = {};
	for _, obj in pairs(targetObjects) do
		if eventArg.EventFlag.BloodSucker and BuffHelper.IsRelation(owner, obj, 'Ally') then
			local RaddHP, reasons = AddActionRestoreHP(actions, owner, obj, addHP);
			ReasonToUpdateBattleEventMulti(obj, ds, reasons, connectID, 0);
			DirectDamageByType(ds, obj, 'BloodWitch', -RaddHP, math.min(obj.MaxHP, obj.HP + RaddHP), false, false, connectID, 0);
		elseif eventArg.EventFlag.BindingPower and BuffHelper.IsRelation(owner, obj, 'Enemy') then
			InsertBuffActions(actions, owner, obj, buff, 1, true);
		end
	end
	return unpack(actions);
end
-- UnitBeingExcluded
function Buff_SummonBeast_UnitBeingExcluded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner and eventArg.Unit ~= giver then
		return;
	end
	local actions = {};
	ApplyUnsummonBeastActions(actions, giver, owner);
	return unpack(actions);
end
function Buff_SummonMachine_UnitBeingExcluded(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner and eventArg.Unit ~= giver then
		return;
	end
	local actions = {};
	ApplyUnsummonMachineActions(actions, giver, owner);
	return unpack(actions);
end
-- CloakingDetected
function Buff_Patrol_CloakingDetected(eventArg, buff, owner, giver, ds)
	if (eventArg.Unit ~= nil and owner ~= eventArg.Unit)
		or owner.HP <= 0
		or GetRelation(owner, eventArg.Target) ~= 'Enemy' then
		return;
	end
	local target = eventArg.Target;
	local targetPos = GetPosition(target);
	local findPos = eventArg.FindPos or targetPos;
	if IsInSight(owner, findPos, true) then
		SetInstantProperty(owner, 'PatrolEnemyPosition', targetPos);
		return Buff_Patrol_FindEnemy(owner, target, nil, ds, false, nil, nil, buff.name) -- 위치를 특정할 수는 있지만 굳이 넣지 않는다.
	end
end
-- PatrolInvalidated
function Buff_Patrol_PatrolInvalidated(eventArg, buff, owner, giver, ds)
	if owner.HP <= 0
		or GetRelation(owner, eventArg.Target) ~= 'Enemy' then
		return;
	end
	local target = eventArg.Target;
	local targetPos = GetPosition(target);
	local findPos = eventArg.FindPos or targetPos;
	if IsInSight(owner, findPos, true) and not eventArg.Target.Cloaking then
		SetInstantProperty(owner, 'PatrolEnemyPosition', targetPos);
		return Buff_Patrol_FindEnemy(owner, target, nil, ds, false, nil, nil, buff.name) -- 위치를 특정할 수는 있지만 굳이 넣지 않는다.
	end
end
--------------------------------------------------------------------------------
-- 우호적 야수 떠남 (야수 해제) [FriendlyBeastAboutToLeave]	Args: Beast(object)
----------------------------------------------------------------------------
-- 거미줄 타기
function Buff_ClimbWeb_FriendlyBeastAboutToLeave(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Beast then
		return;
	end
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	return unpack(actions);
end
-- 땅굴 숨기
function Buff_Burrow_FriendlyBeastAboutToLeave(eventArg, buff, owner, giver, ds)
	if owner ~= eventArg.Beast then
		return;
	end
	local actions = {};
	table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 우호적 기계 참전 (기계 소환/제어권 탈취) [FriendlyMachineHasJoined]	Args: Machine(object), FirstJoin(boolean)
----------------------------------------------------------------------------
-- 관리자 권한
function Buff_ManagerAuthority_FriendlyMachineHasJoined(eventArg, buff, owner, giver, ds)
	-- 기계 소환도 아니고, 제어권 탈취도 아니면 무시
	local isSummoned = GetObjKey(owner) == GetInstantProperty(eventArg.Machine, 'SummonMaster');
	local isHacked = Set.new(GetInstantProperty(owner, 'ControlTakingOverTargets') or {})[GetObjKey(eventArg.Machine)];
	if not isSummoned and not isHacked then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, eventArg.Machine, buff.AddBuff, 1, true);
	return unpack(actions);
end
---
---
function Buff_SecondWind_MindAndBody_ActionPointRestored(eventArg, buff, owner, giver, ds)
	-- 자신의 턴인 상태에서 행동력을 1개 회복할 때마다 36의 과부하가 발생합니다.
	if owner.TurnState.TurnEnded then
		return;
	end
	local actions = {};
	AddActionOverloadForDS(actions, owner, 36, true, true, ds);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 우호적 기계 떠남 (기계 해제) [FriendlyMachineAboutToLeave]	Args: Machine(object), MasterKey(string, object key)
----------------------------------------------------------------------------
-------------------------------------------------------
-- DamageConveyor
-------------------------------------------------------
function DamageConveyor_StarShield(owner, buff, damage, damageBase, damageInfo, test)
	if buff.DuplicateApplyChecker > 0 then
		return damage;
	end
	if damageBase > 0 then
		-- 모든 공격 무효화
		if damageInfo.damage_type == 'Ability' and not test then
			buff.DuplicateApplyChecker = 1;
			AddBattleEvent(owner, 'StarShieldActivated', {Buff = buff.name});
		end
		return 0;
	else
		return damage;
	end
end
-- 폭주
function DamageConveyor_MachineFury(owner, buff, damage, damageBase, damageInfo, test)
	if damage > 0 and damageBase < owner.MaxHP then
		-- 최대 체력보다 작은 모든 공격 무효화
		if not test then
			AddBattleEvent(owner, 'BuffInvokedFromAbility', {Buff = buff.name, EventType = 'FinalHit'});
		end
		return 0, {Type = buff.name, Value = true, ValueType = 'Buff'};
	else
		return damage;
	end
end
-- 동결
function DamageConveyor_Freezing(owner, buff, damage, damageBase, damageInfo, test)
	if damageBase > 0 then
		-- 연출만...
		if damageInfo.damage_type == 'Ability' and not test then
			-- 사망이거나, DischargeOnHit 데미지 타입인 경우에만 연출
			if damage >= owner.HP or (buff.DischargeOnHitDamageType ~= 'None' and buff.DischargeOnHitDamageType == damageInfo.damage_sub_type) then
				AddBattleEvent(owner, 'FreezingReleased', {});
				AddBattleEvent(owner, 'FreezingRemoved', {});
			end
		end
	end
	return damage;
end
-- 눈속임 - 변이
function DamageConveyor_ChangeTrickery(owner, buff, damage, damageBase, damageInfo, test)
	if damageBase > 0 then
		-- 연출만...
		if damageInfo.damage_type == 'Ability' and not test then
			-- 사망시에만 연출
			if damage >= owner.HP then
				AddBattleEvent(owner, 'ChangeTrickeryRemoved', {});
				buff.DuplicateApplyChecker = 1;
			end
		end
	end
	return damage;
end
-- 움츠러든 비늘
function DamageConveyor_ShrinkScale(owner, buff, damage, damageBase, damageInfo, test)
	if damageBase > 0 then
		-- 어빌리티 데미지 계산 공식에서 1회만 적용됨
		if damageInfo.damage_type == 'Ability' and not test then
			buff.DuplicateApplyChecker = 1;
		end
	end
	return damage;
end
-- 위력 조절 기능용
function DamageConveyor_MercyStrike_Temp(owner, buff, damage, damageBase, damageInfo, test)
	if damageBase <= 0
		or owner.HP <= 1
		or owner.HP > damage then
		return damage;
	end
	if not test then
		buff.DuplicateApplyChecker = 1;
	end
	return owner.HP - 1, {Type = buff.name, Value = true, ValueType = 'Buff'};
end
-- 그림자 잔영
function DamageConveyor_ShdowTrace(owner, buff, damage, damageBase, damageInfo, test)
	local testHP = math.floor(owner.MaxHP * buff.ApplyAmount / 100);
	if damage > 0 and damageBase < testHP then
		if not test then
			AddBattleEvent(owner, 'BuffInvokedFromAbility', {Buff = buff.name, EventType = 'FinalHit'});
		end
		return 0, {Type = buff.name, Value = true, ValueType = 'Buff'};
	else
		return damage;
	end
end
-- 무적
function DamageConveyor_Invincible(owner, buff, damage, damageBase, damageInfo, test)
	if damage > 0 then
		return 0, {Type = buff.name, Value = true, ValueType = 'Buff'};
	end
end
-------------------------------------------------------
-- 유틸리티
-------------------------------------------------------
function DoFuncWithExceptBuffStatus(owner, exceptBuffList, statusList, invalidateSight, doFunc)
	local defValue = {
		Movable = true,
		Attackable = true,
		Unconscious = false,
	};

	local prevStat = {};
	for index, buff in ipairs(exceptBuffList) do
		prevStat[index] = {};
		for _, status in ipairs(statusList) do
			prevStat[index][status] = buff[status];
			buff[status] = defValue[status] or false;
		end
		if invalidateSight then
			prevStat[index].Sight = {};
			for sindex, value in ipairs(buff.Base_SightRange) do
				prevStat[index].Sight[sindex] = value;
				buff.Base_SightRange[sindex] = 0;
			end
		end
		InvalidateObject(buff);
	end
	for _, status in ipairs(statusList) do
		InvalidateBuffStatusCache(owner, status);
	end
	InvalidateObject(owner);
	if invalidateSight then
		InvalidateSight(owner);
	end
	
	-- Do Func
	doFunc();

	for index, buff in ipairs(exceptBuffList) do
		for _, status in ipairs(statusList) do
			buff[status] = prevStat[index][status];
		end
		if invalidateSight then
			for sindex, value in ipairs(buff.Base_SightRange) do
				buff.Base_SightRange[sindex] = prevStat[index].Sight[sindex];
			end
		end
		InvalidateObject(buff);
	end
	for _, status in ipairs(statusList) do
		InvalidateBuffStatusCache(owner, status);
	end
	InvalidateObject(owner);
	if invalidateSight then
		InvalidateSight(owner);
	end
end

-- [ResetPhase] 페이즈 리셋
function Buff_VindictiveSpirit_ResetPhase(eventArg, buff, owner, giver, ds)
	buff.DuplicateApplyChecker = 1;
	return Result_RemoveBuff(owner, buff.name, true, owner);
end

-------------------------------------------------------------------------------
-- [MOD] 先制反击（Xzfj Forestall Counterattack）
--
-- 绑定到「预热(WarmUp)」BUFF。持有预热BUFF的角色会获得以下效果：
--   1. 敌人移动到自身半径13格内时 → 发动一次反击
--   2. 半径13格内的敌人使用技能时 → 发动一次反击
--
-- 反击特性：
--   * 使用角色任意攻击技能（远程/近身/范围/对地区/SP/道具均可）；
--   * 技能轮换：每次反击从可用攻击技能列表中轮换选取，避免总用同一个；
--   * 命中率正常计算（不设 Inevitable）；
--   * 不标记 ReactionAbility → 不会触发敌人「电光石火(전광석화)」
--     「阴影猎人(어둠사냥꾼)」等"必然闪避反应攻击"的效果，
--     也不会触发针对反应攻击的联动/反制机制；
--   * 触发无次数限制、无回合限制、无状态限制（满足条件就触发）；
--   * 允许与敌人的反击互相交锋（不跳过敌人的反应攻击）。
--
-- 资源消耗：
--   * 反击是正常的技能施放（不使用 free_action 免费标签），
--     会正常消耗技能的行动力/SP/弹药等资源，并正常进入冷却；
--   * 因此"消耗资源时获得SP"类机制会在反击中生效，
--     连续反击可以积攒SP（如充满气魄后释放SP大招）。
--
-- 防崩溃保护（非限制条件）：
--   * 仅保留"攻击者与目标存活"检查，防止对已死亡单位结算报错。
-------------------------------------------------------------------------------

local XZFJ_FORESTALL_DIST = 13;                        -- 触发半径（格）
local XZFJ_FORESTALL_ROTATE = 'XzfjForestallRotate';   -- 技能轮换索引

--- 目标位置是否在触发半径内
---@param owner unit
---@param pos vector3
local function XzfjForestall_IsInRange(owner, pos)
	return GetDistance3D(GetPosition(owner), pos) <= (XZFJ_FORESTALL_DIST + 0.5);
end

--- 判断技能射程能否覆盖目标位置（直接使用 Range 类的距离字段，无视视野过滤）
--- 引擎的 CalculateRange 会对带 SightFilter 的射程（如 Sphere9_Attack_Outline_Sight）
--- 过滤视野外格子，导致视野外敌人虽然距离在射程内却被判定"够不到"。
--- 因此这里不调用 CalculateRange，直接读取 Range 类的距离参数做纯距离判断，
--- 使视野外敌人也能被正常反击。
---@param owner unit
---@param ability any
---@param targetPos vector3
local function XzfjForestall_CanReach(owner, ability, targetPos)
	local rangeCls = GetClassList('Range') and GetClassList('Range')[ability.TargetRange];
	if not rangeCls then
		return false;
	end
	local reach;
	if rangeCls.Type == 'Sphere' then
		reach = rangeCls.Radius;
	elseif rangeCls.Type == 'Box' or rangeCls.Type == 'Cross' or rangeCls.Type == 'StraightLine' then
		reach = rangeCls.Distance;
	elseif rangeCls.Type == 'Sight' then
		reach = owner.SightRange;
	end
	if not reach then
		return false;
	end
	return GetDistance3D(GetPosition(owner), targetPos) <= (reach + 0.5);
end

--- 获取所有可用的、射程能覆盖 targetPos 的攻击技能
---（远程/近身/范围/对地区/SP/道具均可，不排除任何技能类型，
--- 但目标必须处于该技能射程内，避免近身技能隔空伤人）
---@param owner unit
---@param targetPos vector3
local function XzfjForestall_GetAttacks(owner, targetPos)
	local abilities = GetAvailableAbility(owner, true, true);
	if type(abilities) ~= 'table' then
		return {};
	end
	return table.filter(abilities, function (ability)
		if ability.Type ~= 'Attack' then
			return false;
		end
		return XzfjForestall_CanReach(owner, ability, targetPos);
	end);
end

--- 应用角色拥有的"反应攻击增益天赋"到先制反击的 resultModifier。
--- 原版这些增益分散在反击（CounterAction）、先发制人（Forestallment）、
--- 压制射击（Overwatching）等逻辑中，且多数依赖"敌人攻击结算信息"
--- （AbilityTargetInfos 的命中/闪避状态）。先制反击在敌人行动前出手，
--- 没有该信息，因此这里按原版效果直接应用（取其中更强的"被命中"档位）：
---   * 必中+必暴击：Bonecrusher（肉斩骨断：被命中时反击必中+必暴击）、
---     AcuityForestallment（先见之明）、ImWatching（我在看着，目标暴露时）
---   * 必中：ImPreparedToDie（我准备好了）
---   * 增伤：Revenge（报复，被命中档100%）、RevengeStrikes（复仇连击）、
---     CounterBlow（迎击）、GreySniper（灰狙击手）
---   * 借力增伤：BorrowingEnergy（借力）按"敌人对我方理论最大伤害"
---     （假设被命中且暴击、取各攻击技能伤害最大值）的 ApplyAmount 计算。
--- 注意：BladestormCounterAttack（反击之剑）为特殊斩击机制，不在此处理。
---@param resultModifier table
---@param owner unit
---@param target unit
local function XzfjForestall_ApplyCounterMasteries(resultModifier, owner, target)
	local masteryTable = GetMastery(owner);
	LogAndPrint('[XzfjDebug] ApplyCounterMasteries owner=', owner.name, 'masteryTable=', masteryTable ~= nil);
	if not masteryTable then
		return;
	end
	local function has(name)
		return GetMasteryMastered(masteryTable, name);
	end
	local needInevitable = false;
	local needCritical = false;
	if has('Bonecrusher') then
		needInevitable = true;
		needCritical = true;
		table.insert(resultModifier.BattleEvents, { Object = owner, EventType = 'Bonecrusher' });
		LogAndPrint('[XzfjDebug] Bonecrusher mastered -> insert BattleEvent');
	else
		LogAndPrint('[XzfjDebug] Bonecrusher NOT mastered');
	end
	if has('AcuityForestallment') then
		needInevitable = true;
		needCritical = true;
	end
	if has('ImWatching') and target and HasBuff(target, 'ExposurePosition') then
		needInevitable = true;
		needCritical = true;
	end
	if has('ImPreparedToDie') then
		needInevitable = true;
	end
	if needInevitable then
		resultModifier.Inevitable = true;
	end
	if needCritical then
		resultModifier.CriticalHit = true;
	end
	local damagePuff = 0;
	if has('Revenge') then
		damagePuff = damagePuff + has('Revenge').ApplyAmount2;
	end
	if has('RevengeStrikes') then
		damagePuff = damagePuff + has('RevengeStrikes').ApplyAmount;
	end
	if has('CounterBlow') then
		damagePuff = damagePuff + has('CounterBlow').ApplyAmount4;
	end
	if has('GreySniper') then
		damagePuff = damagePuff + has('GreySniper').ApplyAmount4;
	end
	if damagePuff > 0 then
		resultModifier.DamagePuff = (resultModifier.DamagePuff or 0) + damagePuff;
	end
	-- BorrowingEnergy（借力）：原版按"我方被敌人打中/格挡的实际伤害"返还算增伤。
	-- 先制反击在敌人行动前出手、没有受击数据，因此按理论最大值估算：
	-- 假设我方被敌人的每个攻击技能命中且暴击，取其中伤害最大值，
	-- 再按 ApplyAmount（命中返还比例 30%）计算反击增伤。
	if has('BorrowingEnergy') and target and target.HP and target.HP > 0 then
		local mission = GetMission(owner);
		local weather = mission and mission.Weather and mission.Weather.name or 'Clear';
		local missionTime = mission and mission.MissionTime and mission.MissionTime.name or 'Day';
		local temperature = mission and mission.Temperature and mission.Temperature.name or 'Normal';
		local usingPos = GetPosition(target);
		local maxDamage = 0;
		local targetAbilities = GetAvailableAbility(target, true, true);
		if type(targetAbilities) == 'table' then
			for _, atkAbility in ipairs(targetAbilities) do
				if atkAbility and atkAbility.Type == 'Attack' then
					local damage = GetDamageCalculator(target, owner, atkAbility, weather, temperature, usingPos, 1);
					if damage and damage > 0 then
						local criticalDeal = GetCriticalStrikeDealCalculator(target, owner, atkAbility, nil, missionTime, {});
						if criticalDeal and criticalDeal > 0 then
							damage = damage + damage * criticalDeal / 100;
						end
						if damage > maxDamage then
							maxDamage = damage;
						end
					end
				end
			end
		end
		if maxDamage > 0 then
			local addDamage = math.floor(maxDamage * has('BorrowingEnergy').ApplyAmount / 100);
			if addDamage > 0 then
				resultModifier.DamagePuff_Add = (resultModifier.DamagePuff_Add or 0) + addDamage;
				table.insert(resultModifier.BattleEvents, { Object = owner, EventType = 'MasteryInvokedCustomEvent', Args = {Mastery = 'BorrowingEnergy', EventType = 'Beginning', MissionChat = true} });
			end
		end
	end
end

--- 发动反击：按技能轮换机制选取攻击技能攻击目标。
--- 注意 resultModifier 刻意不设置 ReactionAbility / Inevitable：
---   - 命中率正常计算，享受正常命中增减益；
---   - 敌人电光石火/阴影猎人的"必然闪避反应攻击"只在 reactionAbility
---     为 true 时触发，因此不会生效。
--- 不设置 free_action → 正常消耗技能资源（行动力/SP/冷却），
--- 使"消耗资源时获得SP"类机制在反击中生效。
---@param owner unit
---@param target unit
---@param targetPos vector3
---@param extraFlags? table
---@param hitCount? number
local function XzfjForestall_Attack(owner, target, targetPos, extraFlags, hitCount)
	local attacks = XzfjForestall_GetAttacks(owner, targetPos);
	if #attacks == 0 then
		return nil;
	end
	-- 稳定排序后轮换选取，保证每次反击切换技能
	attacks = SortAbilityList(owner, attacks);
	local rotateIdx = GetInstantProperty(owner, XZFJ_FORESTALL_ROTATE) or 0;
	rotateIdx = rotateIdx % #attacks + 1;
	SetInstantProperty(owner, XZFJ_FORESTALL_ROTATE, rotateIdx);
	local usingAbility = attacks[rotateIdx];

	local resultModifier = {
		BattleEvents = {{Object = owner, EventType = 'XzfjForestallment'}},
		-- 反击禁用击退：引擎在 resultModifier.Moving = true 时强制 knockbackPower = 0（battle.lua）。
		-- 原因：若反击技能带击退（如风弹 GentelBreeze），会把正在执行AI动作/刚完成移动的敌人推走，
		-- 引擎随后无法恢复敌人的AI动作（移动已完成、技能待执行）导致卡死；击退移动还会再次触发
		-- UnitMoved 造成"反击→击退→再反击"连锁。
		Moving = true,
	};
	-- 应用角色拥有的反应攻击增益天赋（肉斩骨断必中必暴击等）
	XzfjForestall_ApplyCounterMasteries(resultModifier, owner, target);
	LogAndPrint('[XzfjDebug] after ApplyCounterMasteries BattleEvents count=', #(resultModifier.BattleEvents or {}), 'inevitable=', tostring(resultModifier.Inevitable), 'crit=', tostring(resultModifier.CriticalHit), 'puff=', tostring(resultModifier.DamagePuff), 'puffAdd=', tostring(resultModifier.DamagePuff_Add));
	if extraFlags then
		for k, v in pairs(extraFlags) do
			resultModifier[k] = v;
		end
	end
	-- 施放前的技能自身冷却配置（施放过程中可能被引擎临时修改，先缓存）
	local coolTime = usingAbility.CoolTime or 0;
	-- PreemptiveOrder 恒为 0：先制反击是"已触发后"的反击，不需要原版压制射击那种
	-- "按触发顺序递增、每档等待 order*2 秒"的排队演出（多人同时对同一敌人反击时，
	-- 每个后续单位都要多等数秒，造成 5-10 秒停顿）。参考原版 mastery.lua 对后续
	-- 压制反击的处理（action.directing_config.PreemptiveOrder = 0）。
	-- 多个单位齐射的演出交给引擎自行调度，若演出重叠可由引擎内部处理。
	local action = Result_UseAbilityTarget(owner, usingAbility.name, target, resultModifier, true, {NoCamera=true, Preemptive=true, PreemptiveOrder=0, ForestallFast=true});
	-- 不设置 free_action=true：作为正常消耗资源的技能施放
	-- 最终可用性校验：存活 + 目标仍在技能射程内（无视视野，防止敌人移动后脱靶）
	action.final_useable_checker = function()
		return owner.HP > 0 and target.HP > 0
			and XzfjForestall_CanReach(owner, usingAbility, targetPos);
	end;
	-- 反击成功后：触发角色全技能 CD-1（含本次使用的技能）。
	-- 用静态的 AbilityPropertyUpdated 动作在施放后统一设置冷却值：
	--   ① 本次使用的技能：引擎施放后 Cool=CoolTime+1，反击结束全技能-1 → 应为 CoolTime-1；
	--   ② 其余技能：当前 Cool - 1（最低 0）。
	-- 例：A(无CD)/B(CD2)/C(CD3) 轮换 A→B→C 各反击一次后进入我方回合：
	--    A=0 可用、B=0 可用、C=2（还需2回合），不会阻碍主动攻击。
	local onSuccess = {};
	local allAbilities = GetAllAbility(owner, false, true);
	for _, ab in ipairs(allAbilities) do
		if not ab.name then
		elseif ab.name == usingAbility.name then
			local thisCool = math.max((coolTime or 0) - 1, 0);
			table.insert(onSuccess, Result_AbilityPropertyUpdated('Cool', thisCool, owner, ab.name, true));
		else
			local nextCool = math.max((ab.Cool or 0) - 1, 0);
			if nextCool ~= (ab.Cool or 0) then
				table.insert(onSuccess, Result_AbilityPropertyUpdated('Cool', nextCool, owner, ab.name, true));
			end
		end
	end
	action.on_success_actions = onSuccess;
	return action;
end

-------------------------------------------------------------------------------
-- 事件处理：13格内的敌人使用技能
-- 注意：不跳过敌人的反应攻击（Preemptive），允许与敌人互相反击。
-- 敌方反击天赋自身带每回合/重复次数保护，因此互相交锋是有限的，
-- 会在一方被击杀或敌方次数用尽后自然停止。
-------------------------------------------------------------------------------
function Buff_XzfjForestall_PreAbilityUsing(eventArg, buff, owner, giver, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or eventArg.Unit.HP <= 0 then
		return;
	end
	local targetPos = GetPosition(eventArg.Unit);
	if not XzfjForestall_IsInRange(owner, targetPos) then
		return;
	end
	return XzfjForestall_Attack(owner, eventArg.Unit, targetPos);
end

-------------------------------------------------------------------------------
-- 事件处理：敌人一次移动动作结束（从A点移动到B点 → 只触发一次反击）
-- 注意：不使用 UnitMovedSingleStep（那是每移动一格触发一次，会导致敌人
-- 移动6格触发6次反击）；改为 UnitMoved（整个移动动作结束触发一次），
-- 符合"敌人每次移动触发一次反击"的预期，且不影响其他行动的触发。
-------------------------------------------------------------------------------
function Buff_XzfjForestall_UnitMoved(eventArg, buff, owner, giver, ds)
	if eventArg.Unit.HP <= 0
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or SafeIndex(eventArg, 'Invoker', 'Unit') == owner then
		return;
	end
	-- 落点：移动动作结束时 eventArg.Position 为移动后位置
	local p = eventArg.Position or GetPosition(eventArg.Unit);
	if not XzfjForestall_IsInRange(owner, p) then
		return;
	end
	local hitCount = eventArg.OverwatchHitCount or 0;
	eventArg.OverwatchHitCount = hitCount + 1;
	local action = XzfjForestall_Attack(owner, eventArg.Unit, p, {Moving = true}, hitCount);
	if action == nil then
		return;
	end
	return action;
end

