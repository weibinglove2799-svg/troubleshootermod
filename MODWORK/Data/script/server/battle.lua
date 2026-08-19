------------------------------------------------------------------------------------------------
-------------------------------------- 전투 계산 공식 ----------------------------------------
------------------------------------------------------------------------------------------------
-- Attacker, Defender 는 Object(Object.xml)의 Object 값
-- ability는  Ability(Ability.xml)의 Object 의 값 
-- phase = Primary
------------------------------------------------------------------------------------------------
function Battle(Attacker, Defender, ability, actions, phase, resultModifier, usingPos, chainIndex, detailInfo, perfChecker)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	perfChecker:StartRoutine('Initialize');
	local masteryTable_Attacker = GetMastery(Attacker);
	local masteryTable_Defender = nil;
	if Defender ~= nil then
		masteryTable_Defender = GetMastery(Defender);
	end

	resultModifier = resultModifier or {};
	if HasBuff(Attacker, 'GentleSlap') then
		ForceNewIndex(resultModifier, 'DefenderState', 'BlockWhenHit');
	elseif HasBuff(Attacker, 'CurseOfFailure') then
		ForceNewIndex(resultModifier, 'DefenderState', 'Dodge');
	end
	
	local damageFlag = BuildDamageFlagFromResultModifier(resultModifier);
	
	local weather = 'Clear';
	local missionTime = 'Day';
	local temperature = 'Normal';
	local isCovered = false;
	
	perfChecker:StartRoutine('ConfigureEnviornment');
	if IsMissionServer() then
		local mission = GetMission(Attacker);
		weather = mission.Weather.name;
		missionTime = mission.MissionTime.name;
		temperature = mission.Temperature.name;
		isCovered = IsCoveredPosition(mission, GetPosition(Defender));
	end
	
	phase = phase or 'Primary';
	local defenderState = 'Hit';
	local attackerState = 'Normal';
	local knockbackPower = ability.KnockbackPower;
	
	-- C1. 피해량을 계산 합니다
	perfChecker:StartRoutine('DamageCalculation');
	perfChecker:Dive();
	local damage = GetDamageCalculator(Attacker, Defender, ability, weather, temperature, usingPos, chainIndex, nil, SafeIndex(resultModifier, 'DamagePuff_Add'), detailInfo, perfChecker, damageFlag);
	perfChecker:Rise();
	if SafeIndex(resultModifier, 'DamagePuff') then
		damage = damage * (100 + SafeIndex(resultModifier, 'DamagePuff')) / 100;
	end
	-- C2. 명중률을 계산 합니다 
	perfChecker:StartRoutine('HitRateCalculation');
	local hitRate, hitRateReason = ability.GetHitRateCalculator(Attacker, Defender, ability, usingPos, weather, missionTime, temperature, resultModifier, nil--[[aiFlag]], detailInfo);
	
	-- C3. 치명타 적중률을 계산 합니다 
	perfChecker:StartRoutine('CSCCalculation');
	perfChecker:Dive();
	local criticalStrikeChance = GetCriticalStrikeChanceCalculator(Attacker, Defender, ability, weather, missionTime, isCovered, resultModifier, detailInfo, damageFlag, perfChecker);
	perfChecker:Rise();
	-- C4. 적 방어 확률을 계산 합니다 
	perfChecker:StartRoutine('BlockCalculation');
	local blockRate = GetBlockRateCalculator(Attacker, Defender, ability, missionTime, detailInfo, resultModifier, damageFlag);
	-- C5. 극대화 비율을 계산 합니다.
	perfChecker:StartRoutine('CSDCalculation');
	local criticalDeal = GetCriticalStrikeDealCalculator(Attacker, Defender, ability, detailInfo, missionTime, resultModifier);
	
	-- 1. Select Attacker State --
	perfChecker:StartRoutine('DecideAttackerState');
	local resultModifierAttackerState = SafeIndex(resultModifier, 'AttackerState');
	local isEnableCriticalStrikeChance = IsEnableCriticalStrikeChance(criticalStrikeChance, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damageFlag, damage);
	if resultModifierAttackerState and resultModifierAttackerState ~= 'NotUsed' then
		attackerState = resultModifierAttackerState;
	elseif isEnableCriticalStrikeChance then
		attackerState = 'Critical';
	end
		
	-- 2. Select Defender State --	
	perfChecker:StartRoutine('DecideDodge');
	local reactionAbility = SafeIndex(resultModifier, 'ReactionAbility') and true or false;	-- 반응 공격 여부
	local resultModifierDefenderState = SafeIndex(resultModifier, 'DefenderState');
	local isEnableDodge = IsEnableDodge(actions, hitRate, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, reactionAbility, missionTime, damageFlag, damage);
	perfChecker:StartRoutine('DecideBlock');
	local isEnableBlock = IsEnableBlock(blockRate, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damageFlag, damage);
	if resultModifierDefenderState and resultModifierDefenderState ~= 'NotUsed' then
		if resultModifierDefenderState == 'BlockWhenHit' then
			defenderState = isEnableDodge and 'Dodge' or 'Block'
		else
			defenderState = resultModifierDefenderState
		end
	elseif ability.Type == 'Heal' then
		defenderState = 'Heal'
	else
		defenderState = isEnableDodge and 'Dodge' or (isEnableBlock and 'Block' or defenderState)
	end
	
	perfChecker:StartRoutine('Miscellaneous');
	-- attackerState와 defenderState의 변경 또는 데미지 증가가 필요한 것들을 미리 처리한다.
	if ability.Type ~= 'Heal' and Defender then
		damage, attackerState, defenderState, knockbackPower = GetModifyResultActions_PreState(actions, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage, attackerState, defenderState, knockbackPower, damageFlag, detailInfo, resultModifier, missionTime);
	end
	if defenderState == 'Block' then
		attackerState = 'Normal';
	end
	
	-- Calculated Damaged --
	if attackerState == 'Critical' then
		damage = damage + damage * criticalDeal/100;
	end	
	
	perfChecker:StartRoutine('CalculateMinDamage');
	local minDamage = CalculateAbilityMinDamage(ability, phase, Attacker, Defender);
	
	perfChecker:StartRoutine('FinalizeDamage');
	if defenderState == 'Dodge' then
		damage = 0;
	elseif defenderState == 'Heal' then
		damage = -1 * damage;
	elseif defenderState == 'Block' then
		local damagePreBlocked = damage;
		local damageReduce = GetDamageReduceOnBlockCalculator(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, resultModifier, damageFlag);		
		damage = math.max(minDamage, damage * (1 - damageReduce));
		damageBlocked = math.floor(math.max(damagePreBlocked - damage, 0));
	else
		damage = math.max(minDamage, damage);
	end
	
	-- 5. 확정된 state 에 따른 피해량 Modify
	perfChecker:StartRoutine('ApplyResultModifier');
	if SafeIndex(resultModifier, 'DamageAdjust') == 'Use' and defenderState ~= 'Dodge' then
		damage = ResultModifier_Damage(damage, resultModifier);
	else
		damage, attackerState, defenderState, knockbackPower = GetModifyResultActions_Final(actions, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage, attackerState, defenderState, knockbackPower, damageFlag);
	end
	damage = math.floor(damage);
	
	if knockbackPower > 0 and SafeIndex(resultModifier, 'Moving') then
		knockbackPower = 0;
		table.insert(actions, Result_FireWorldEvent('MovingKnockbackIgnored', {Attacker=Attacker, Defender=Defender}, nil, true));
	end
	
	perfChecker:StartRoutine('ProcessAfterEvent');
	-- 5. 공격에 따른 이벤트.
	-- 대미지, 공격상태를 변경하지 않는다.
	-- 공격자와 피격자의 결과값이 더 이상 변하지 않고 해당 결과 값에 따라 변하는 특성들을 처리한다. 후처리 부.
	-- 사망 유무에 따라 버프 적용 유무가 달라질 수 있으므로, 더미 데미지 액션으로 데미지 테스트를 해서 사망 유무를 알아냄
	local realDamage = damage;
	if IsMissionServer() then
		local damageInfo = Result_Damage(damage, attackerState, defenderState, Attacker, Defender, 'Ability', ability.SubType, ability, resultModifier and resultModifier.NoReward or nil, damageBlocked);
		realDamage = ApplyDamageTest(Defender, damage, damageInfo);
	end
	local isDead = (Defender.HP <= realDamage);
	local buffApplied = AddBattleResultEventAction(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, resultModifier, isDead, realDamage, damageFlag);
	if IsMissionServer() then
		LogAndPrint(string.format('[%s]>>== Battle ==: [%s] use [%s] Ability to [%s]', GetMissionGID(Attacker), Attacker.name, ability.name, SafeIndex(Defender, 'name')));
		LogAndPrintDev('Damage: ', damage, 'State: ', attackerState..'/'..defenderState, 'KB:', knockbackPower);
		LogAndPrintDev('==============================================================');
	end
	return damage, attackerState, defenderState, knockbackPower, damageBlocked, buffApplied, damageFlag;
end
----------------------------------------------------------------
-- 방어시 피해량 결정 함수.
-----------------------------------------------------------------
function GetDamageReduceOnBlockCalculator(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, resultModifier, damageFlag)
	local damageReduce = 50;
	-- 성문 파괴.
	if IsGetAbilitySubType(ability, 'Slashing') then
		local mastery_BreakCastleGate = GetMasteryMastered(masteryTable_Attacker, 'BreakCastleGate');
		if mastery_BreakCastleGate then
			damageReduce = damageReduce - damageReduce * mastery_BreakCastleGate.ApplyAmount;
			AddMasteryInvokedEvent(Attacker, mastery_BreakCastleGate.name, 'FirstHit');
		end
		
		-- 칼날발톱 대검 시리즈
		if ability.HitRateType == 'Melee' then
			local mastery_TwoHandSword_Talon = GetMasteryMasteredList(masteryTable_Attacker, {'TwoHandSword_Talon', 'TwoHandSword_Talon_Rare', 'TwoHandSword_Talon_Epic'});
			if mastery_TwoHandSword_Talon then
				damageReduce = damageReduce - mastery_TwoHandSword_Talon.ApplyAmount;
				AddMasteryInvokedEvent(Attacker, mastery_TwoHandSword_Talon.name, 'FirstHit');
			end
		end
	end
	-- 화경
	if ability.HitRateType == 'Melee' then
		local mastery_NeutralizingEnergy = GetMasteryMastered(masteryTable_Defender, 'NeutralizingEnergy');
		if mastery_NeutralizingEnergy then
			-- 정중동
			local mastery_MartialArtStaticMonement = GetMasteryMastered(masteryTable_Defender, 'MartialArtStaticMonement');
			if mastery_MartialArtStaticMonement then
				damageReduce = damageReduce + mastery_MartialArtStaticMonement.ApplyAmount;
				AddMasteryInvokedEvent(Defender, mastery_NeutralizingEnergy.name, 'FirstHit');
				AddMasteryInvokedEvent(Defender, mastery_MartialArtStaticMonement.name, 'FirstHit');
			end
		end
	end
	-- 파스칼의 작업용 보호구
	local mastery_Amulet_Pascal = GetMasteryMastered(masteryTable_Defender, 'Amulet_Pascal');
	if mastery_Amulet_Pascal then
		damageReduce = damageReduce + mastery_Amulet_Pascal.ApplyAmount;
		AddMasteryInvokedEvent(Defender, mastery_Amulet_Pascal.name, 'FirstHit');
	end
	-- 패기만만
	local mastery_EbullientSpirit = GetMasteryMastered(masteryTable_Attacker, 'EbullientSpirit');
	if mastery_EbullientSpirit then
		local reduceAmount = math.floor(mastery_EbullientSpirit.CustomCacheData / mastery_EbullientSpirit.ApplyAmount) * mastery_EbullientSpirit.ApplyAmount2;
		damageReduce = damageReduce - reduceAmount;
		AddMasteryInvokedEvent(Attacker, mastery_EbullientSpirit.name, 'FirstHit');
	end
	-- 원거리 방어 기동
	local mastery_Module_ForceDefenceReaction = GetMasteryMastered(masteryTable_Defender, 'Module_ForceDefenceReaction');
	if mastery_Module_ForceDefenceReaction and IsRangedAttackAbility(ability) and Defender.Cost >= mastery_Module_ForceDefenceReaction.ApplyAmount2 then
		damageReduce = damageReduce + mastery_Module_ForceDefenceReaction.ApplyAmount;
		damageFlag.Module_ForceDefenceReaction = true;
		AddMasteryInvokedEvent(Defender, mastery_Module_ForceDefenceReaction.name, 'FirstHit');
	end
	
	return math.max(0, damageReduce) / 100;
end
----------------------------------------------------------------
-- 각 상황 판단 함수. 회피/ 방어/ 크리티컬
-----------------------------------------------------------------
function IsEnableDodge(actions, hitRate, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, reactionAbility, missionTime, damageFlag, damage)
	-- 회복 어빌리티 & 어빌리티 회피 불가
	if ability.Type == 'Heal' or ability.IgnoreDodge then
		return false, 'Heal';
	end
	-- 행운 / 공격자
	local buff_Luck_Attacker = GetBuff(Attacker, 'Luck');
	if buff_Luck_Attacker and buff_Luck_Attacker.DuplicateApplyChecker == 0 then
		AddBattleEvent(Attacker, 'BuffRevealedFromAbility', {Buff = buff_Luck_Attacker.name, EventType = 'FirstHit'});
		return false, buff_Luck_Attacker.name;
	end
	-- 행운 / 피격자
	local buff_Luck_Defender = GetBuff(Defender, 'Luck');
	if buff_Luck_Defender and buff_Luck_Defender.DuplicateApplyChecker <= 1 then
		-- 무조건 명중 (공격자 특성)
		local ignoreDodge, reason = IsIgnoreDodge_Attacker(actions, Attacker, Defender, ability, masteryTable_Attacker, masteryTable_Defender, reactionAbility, missionTime, damageFlag, true);
		if ignoreDodge then
			AddBattleEvent(Defender, 'BuffRevealedFromAbility', {Buff = buff_Luck_Defender.name, EventType = 'FirstHit'});
			buff_Luck_Defender.DuplicateApplyChecker = 1;
			return true, buff_Luck_Defender.name;
		end
	end
	-- 무조건 명중 (공격자 특성)
	local ignoreDodge, reason = IsIgnoreDodge_Attacker(actions, Attacker, Defender, ability, masteryTable_Attacker, masteryTable_Defender, reactionAbility, missionTime, damageFlag);
	-- 들고양이
	local mastery_WildCat = GetMasteryMastered(masteryTable_Defender, 'WildCat');
	if mastery_WildCat and ignoreDodge and ability.Type == 'Attack' and GetRelation(Defender, Attacker) == 'Enemy' then	
		ignoreDodge = false;
	end
	-- 신기루
	local mastery_Mirage = GetMasteryMastered(masteryTable_Defender, 'Mirage');
	if mastery_Mirage and ignoreDodge and ability.Type == 'Attack' and (ability.HitRateType == 'Force' or ability.HitRateType == 'Fall' or ability.HitRateType == 'Throw') then
		ignoreDodge = false;
	end
	if ignoreDodge then
		return false, reason;
	end
	-- 무조건 회피 (피격자 특성)
	local isEnable, reason = IsEnableDodge_Defender(actions, Attacker, Defender, ability, masteryTable_Attacker, masteryTable_Defender, reactionAbility, missionTime, damageFlag);
	if isEnable ~= nil then
		return isEnable, reason;
	end
	-- 행운으로 인한 회피는 위의 로직들로 못 피했을 때만 발동
	if buff_Luck_Defender and buff_Luck_Defender.DuplicateApplyChecker <= 1 then
		AddBattleEvent(Defender, 'BuffRevealedFromAbility', {Buff = buff_Luck_Defender.name, EventType = 'FirstHit'});
		buff_Luck_Defender.DuplicateApplyChecker = 1;
		return true, buff_Luck_Defender.name;
	end
	-- 회피율 테스트
	return not AbilityHitRateTest(Attacker, Defender, hitRate, damage);
end
function IsIgnoreDodge_Attacker(actions, Attacker, Defender, ability, masteryTable_Attacker, masteryTable_Defender, reactionAbility, missionTime, damageFlag, test)
	-- 결정타
	if ability.Type == 'Attack' then
		local mastery_FinalBlow = GetMasteryMastered(masteryTable_Attacker, 'FinalBlow');
		if mastery_FinalBlow then
			if Defender.HP < Defender.MaxHP * mastery_FinalBlow.ApplyAmount2/100 then
				if not test then
					damageFlag.FinalBlow = true;
				end
				return true, mastery_FinalBlow.name;
			end
		end
	end
	-- 특성 발동으로 인한 무조건 명중 어빌리티 사용 (ex. 연격, 살을 주고 뼈를 취한다.)
	if damageFlag.Inevitable then
		return true, 'Inevitable';
	end
	-- 특성 기습 & 어둠사냥꾼
	if Defender ~= nil and IsDarkTime(missionTime) then
		local mastery_Ambush = GetMasteryMastered(masteryTable_Attacker, 'Ambush');
		local mastery_DarkHunter = GetMasteryMastered(masteryTable_Attacker, 'DarkHunter');
		if mastery_Ambush and mastery_DarkHunter and not HasBuff(Attacker, 'ExposurePosition') then
			local group_Sleep_List = GetBuffType(Defender, nil, nil, mastery_DarkHunter.BuffGroup.name);
			if #group_Sleep_List > 0 or Defender.PreBattleState then
				return true, mastery_Ambush.name;
			end
		end
	end	
	-- 특성 신중함
	local mastery_Discretion = GetMasteryMastered(masteryTable_Attacker, 'Discretion');
	if mastery_Discretion and IsStableAttack(Attacker) and IsUnprotectedExposureState(Defender) then
		if not test then
			AddMasteryInvokedEvent(Attacker, mastery_Discretion.name, 'FirstHit');
		end
		return true, mastery_Discretion.name;
	end
	-- 특성 그림자 암살
	local mastery_ShadowAssasine = GetMasteryMastered(masteryTable_Attacker, 'ShadowAssasine');
	if mastery_ShadowAssasine and not Attacker.ExposedByEnemy then
		return true, mastery_ShadowAssasine.name;
	end

	-- 도로리 반향정위
	local mastery_DororiEcholocation = GetMasteryMastered(masteryTable_Attacker, 'DororiEcholocation');
	if mastery_DororiEcholocation and HasBuff(Defender, mastery_DororiEcholocation.Buff.name) then
		return true, mastery_DororiEcholocation.name;
	end

	-- 광전사 - 3 세트
	local mastery_BerserkerSet3 = GetMasteryMastered(masteryTable_Attacker, 'BerserkerSet3');
	if mastery_BerserkerSet3 and reactionAbility and HasBuffType(Attacker, nil, nil, mastery_BerserkerSet3.BuffGroup.name, true) then
		return true, mastery_BerserkerSet3.name;
	end
	-- 광전사 - 5 세트
	local mastery_BerserkerSet5 = GetMasteryMastered(masteryTable_Attacker, 'BerserkerSet5');
	if mastery_BerserkerSet5 and HasBuffType(Attacker, nil, nil, mastery_BerserkerSet5.BuffGroup.name, true) then
		if Defender.HP <= Defender.MaxHP * mastery_BerserkerSet5.ApplyAmount / 100 then
			return true, mastery_BerserkerSet5.name;
		end
	end
	-- 사과 떨구기
	local mastery_AppleDrop = GetMasteryMastered(masteryTable_Attacker, 'AppleDrop');
	if mastery_AppleDrop and ability.Type == 'Attack' and ability.HitRateType == 'Force' then
		if IsUnprotectedExposureState(Defender) then
			return true, mastery_AppleDrop.name;
		end
	end

	-- 적시타
	local mastery_TimelyHit = GetMasteryMastered(masteryTable_Attacker, 'TimelyHit');
	if mastery_TimelyHit and ability.Type == 'Attack' and (SafeIndex(damageFlag, 'ReactionAbility') or SafeIndex(damageFlag, 'Counter')) then
		return true, mastery_TimelyHit.name;
	end

	-- 정밀 조준 강화
	local mastery_Module_SuperAim = GetMasteryMastered(masteryTable_Attacker, 'Module_SuperAim');
	if mastery_Module_SuperAim and HasBuff(Defender, mastery_Module_SuperAim.Buff.name) then
		return true, mastery_Module_SuperAim.name;
	end

	-- 난도질
	local mastery_SliceAndDice = GetMasteryMastered(masteryTable_Attacker, 'SliceAndDice');
	if mastery_SliceAndDice and mastery_SliceAndDice.CountChecker > 0 then
		return true, mastery_SliceAndDice.name;
	end

	-- 모방 공격
	local mastery_ImitationAttack = GetMasteryMastered(masteryTable_Attacker, 'ImitationAttack');
	if mastery_ImitationAttack and not Attacker.TurnState.TurnEnded and not HasBuff(Attacker, 'Confusion') then
		local dmgTypeMap = GetInstantProperty(Attacker, mastery_ImitationAttack.name);
		local limit = GetImitationAttackLimit(Attacker, mastery_ImitationAttack, masteryTable_Attacker);
		if (SafeIndex(dmgTypeMap, 1, ability.SubType) or SafeIndex(dmgTypeMap, 2, ability.HitRateType)) and mastery_ImitationAttack.CountChecker < limit then
			if not test then
				AddMasteryInvokedEvent(Attacker, mastery_ImitationAttack.name, 'FirstHit');
				mastery_ImitationAttack.CountChecker = mastery_ImitationAttack.CountChecker + 1;
				table.insert(actions, Result_BuffPropertyUpdated('Lv', limit - mastery_ImitationAttack.CountChecker, Attacker, mastery_ImitationAttack.name, nil, true, false, true));

				-- 교묘한 모방 공격
				local mastery_CleverImitationAttack = GetMasteryMastered(masteryTable_Attacker, 'CleverImitationAttack');
				if mastery_CleverImitationAttack and IsCoverStateNone(Attacker, Defender, masteryTable_Attacker, GetMastery(Defender)) then
					mastery_CleverImitationAttack.DuplicateApplyChecker = 1;
					local applySet = GetInstantProperty(Attacker, mastery_CleverImitationAttack.name);
					if applySet == nil then
						applySet = {};
						SetInstantProperty(Attacker, mastery_CleverImitationAttack.name, applySet);
					end
					applySet[GetObjKey(Defender)] = true;
				end
			end
			return true, mastery_ImitationAttack.name;
		end
	end

	-- 거미줄 춤
	local mastery_WebDance = GetMasteryMastered(masteryTable_Attacker, 'WebDance');
	if mastery_WebDance then
		if (IsStableAttack(Attacker) or damageFlag.ReactionAbility or damageFlag.Counter) 
			and table.exist(GetFieldEffectByPosition(Attacker, GetPosition(Attacker)), function(fei) return fei.Owner.name == 'Web' end) then
			return true, mastery_WebDance.name;
		end
	end

	-- 해골 가면
	local mastery_Amulet_Munggo_SkullMask = GetMasteryMastered(masteryTable_Attacker, 'Amulet_Munggo_SkullMask');
	if mastery_Amulet_Munggo_SkullMask then
		if ability.Type == 'Attack'
			and ability.HitRateType == 'Melee'
			and Attacker.HP / Attacker.MaxHP * 100 <= mastery_Amulet_Munggo_SkullMask.ApplyAmount
			and mastery_Amulet_Munggo_SkullMask.CountChecker < mastery_Amulet_Munggo_SkullMask.ApplyAmount2 then
			if not test then
				-- damageFlag 체크만, 카운트 증가 & 연출은 GetModifyResultActions_PreState에서 처리
				damageFlag.Amulet_Munggo_SkullMask = true;
			end
			return true, mastery_Amulet_Munggo_SkullMask.name;
		end
	end

	-- 쓰나미
	local mastery_TidalWave = GetMasteryMastered(masteryTable_Attacker, 'TidalWave');
	if mastery_TidalWave and IsGetAbilitySubType(ability, mastery_TidalWave.Type.name) then
		return true, mastery_TidalWave.name;
	end

	return false;
end
function IsEnableDodge_Defender(actions, Attacker, Defender, ability, masteryTable_Attacker, masteryTable_Defender, reactionAbility, missionTime, damageFlag)	
	-- 반응 공격 회피
	if reactionAbility then
		-- 전광석화
		local mastery_LightningReflexes = GetMasteryMastered(masteryTable_Defender, 'LightningReflexes');
		if mastery_LightningReflexes and not GetBuffStatus(Defender, 'Unconscious', 'Or') then
			-- 전광석화는 반응 사격만 회피 가능
			local isEnableDodgeAbility = ability.HitRateType ~= 'Melee';
			local alreadyApplied = GetInstantProperty(Defender, 'LightningReflexesUsed');
			if IsDarkTime(missionTime) then
				local mastery_DarkHunter = GetMasteryMastered(masteryTable_Defender, 'DarkHunter');
				if mastery_DarkHunter and not HasBuff(Defender, 'ExposurePosition') then
					alreadyApplied = false; -- 최초 1회 뿐만 아니라 계속 피한다.
					AddMasteryInvokedEvent(Defender, mastery_DarkHunter.name, 'FirstHit');
					-- 어둠사냥꾼은 반응 공격 모두 회피 가능
					isEnableDodgeAbility = true;
				end
			end
			-- 헛다리 짚기, 거침없는 발놀림
			for _, countExpandTarget in ipairs({{'Stepover', 'ApplyAmount5'}
												, {'OverwhelmCleverFoot', 'ApplyAmount3'}}) do
				local reflexCountExander = countExpandTarget[1];
				local applyAmountKey = countExpandTarget[2];
				local expanderMastery = GetMasteryMastered(masteryTable_Defender, reflexCountExander);
				if expanderMastery and ability.HitRateType ~= 'Melee' 
					and alreadyApplied and expanderMastery.CountChecker < expanderMastery[applyAmountKey] 
				then
					alreadyApplied = false; -- 최초 1회 외에 추가로 피한다
					AddMasteryInvokedEvent(Defender, expanderMastery.name, 'FirstHit');
					expanderMastery.CountChecker = expanderMastery.CountChecker + 1;
					break;
				end
			end
			-- 거미줄 춤
			local mastery_WebDance = GetMasteryMastered(masteryTable_Defender, 'WebDance');
			if alreadyApplied and mastery_WebDance and table.exist(GetFieldEffectByPosition(Defender, GetPosition(Defender)), function(fei) return fei.Owner.name == 'Web' end) then
				alreadyApplied = false;
				isEnableDodgeAbility = true;
				AddMasteryInvokedEvent(Defender, mastery_WebDance.name, 'FirstHit');
			end
			-- 모든 일에는 운이 따라야 한다.
			local mastery_AllFollowingLuck = GetMasteryMastered(masteryTable_Defender, 'AllFollowingLuck');
			if alreadyApplied and IsUnprotectedExposureState(Defender, GetPosition(Defender), true) and mastery_AllFollowingLuck and mastery_AllFollowingLuck.DuplicateApplyChecker < mastery_AllFollowingLuck.ApplyAmount2 then
				alreadyApplied = false; -- 최초 1회 외에 추가로 피한다
				AddMasteryInvokedEvent(Defender, mastery_AllFollowingLuck.name, 'FirstHit');
				mastery_AllFollowingLuck.DuplicateApplyChecker = mastery_AllFollowingLuck.DuplicateApplyChecker + 1;
			end
			if not alreadyApplied and isEnableDodgeAbility then
				SetInstantProperty(Defender, 'LightningReflexesUsed', true);	-- 해당 프로퍼티의 초기화는 이벤트 핸들러에서 맡는다
				AddMasteryInvokedEvent(Defender, 'LightningReflexes', 'FirstHit');
				damageFlag.LightningReflexes = true;
				-- 일기당천
				local mastery_MatchlessWarrior = GetMasteryMastered(masteryTable_Defender, 'MatchlessWarrior');
				if mastery_MatchlessWarrior then
					AddMasteryInvokedEvent(Defender, mastery_MatchlessWarrior.name, 'FirstHit');
					-- 실제 효과는 이벤트 핸들러에서 처리됨
				end
				-- 날렵한 발놀림
				local mastery_NimbleFootwork = GetMasteryMastered(masteryTable_Defender, 'NimbleFootwork');
				if mastery_NimbleFootwork then
					AddMasteryInvokedEvent(Defender, mastery_NimbleFootwork.name, 'FirstHit');
					-- 실제 효과는 이벤트 핸들러에서 처리됨
				end
				-- 거리의 싸움꾼
				local mastery_StreetFighter = GetMasteryMastered(masteryTable_Defender, 'StreetFighter');
				if mastery_StreetFighter then
					AddMasteryInvokedEvent(Defender, mastery_StreetFighter.name, 'FirstHit');
					-- 실제 효과는 이벤트 핸들러에서 처리됨
				end
				-- 전장을 뚫어라
				local mastery_DrillBattleField = GetMasteryMastered(masteryTable_Defender, 'DrillBattleField');
				if mastery_DrillBattleField then
					AddMasteryInvokedEvent(Defender, mastery_DrillBattleField.name, 'FirstHit');
					-- 실제 효과는 이벤트 핸들러에서 처리됨
				end
				-- 빗나간 죽음
				local mastery_LuckyCheatDeath = GetMasteryMastered(masteryTable_Defender, 'LuckyCheatDeath');
				if mastery_LuckyCheatDeath then
					local adjustValue = GetInstantProperty(Defender, mastery_LuckyCheatDeath.name) or 0;
					adjustValue = adjustValue + mastery_LuckyCheatDeath.ApplyAmount3;
					SetInstantProperty(Defender, mastery_LuckyCheatDeath.name, adjustValue);
				end
				-- 달빛의 괴수
				local mastery_MoonMonster = GetMasteryMastered(masteryTable_Defender, 'MoonMonster');
				if mastery_MoonMonster then
					AddMasteryInvokedEvent(Defender, mastery_MoonMonster.name, 'FirstHit');
					-- 실제 효과는 이벤트 핸들러에서 처리됨
				end
				return true, 'LightningReflexes'
			end
		end
		-- 질풍신뢰는 반응 공격 모두 회피 가능
		if HasBuff(Defender, 'FlashAura') and not GetBuffStatus(Defender, 'Unconscious', 'Or') then
			AddBattleEvent(Defender, 'BuffRevealedFromAbility', {Buff = 'FlashAura', EventType = 'FirstHit'});
			return true, 'FlashAura';
		end
		-- 고속 호버링
		local mastery_Module_HighSpeedHovering = GetMasteryMastered(masteryTable_Defender, 'Module_HighSpeedHovering');
		if mastery_Module_HighSpeedHovering and not GetBuffStatus(Defender, 'Unconscious', 'Or') and mastery_Module_HighSpeedHovering.DuplicateApplyChecker > 0 then
			AddMasteryInvokedEvent(Defender, mastery_Module_HighSpeedHovering.name, 'FirstHit');
			return true, mastery_Module_HighSpeedHovering.name;
		end
		-- 자동 회피 반응
		local mastery_Module_LightningReflexes = GetMasteryMastered(masteryTable_Defender, 'Module_LightningReflexes');
		if mastery_Module_LightningReflexes and not GetBuffStatus(Defender, 'Unconscious', 'Or') then
			local limit = mastery_Module_LightningReflexes.ApplyAmount2;
			-- 향상된 자동 회피 반응
			local mastery_Module_EnhancedLightningReflexes = GetMasteryMastered(masteryTable_Defender, 'Module_EnhancedLightningReflexes');
			if mastery_Module_EnhancedLightningReflexes then
				limit = limit + mastery_Module_EnhancedLightningReflexes.ApplyAmount;
			end
			if mastery_Module_LightningReflexes.CountChecker < limit then
				local needCost = (mastery_Module_LightningReflexes.DuplicateApplyChecker + 1) * mastery_Module_LightningReflexes.ApplyAmount;
				if needCost <= Defender.Cost then
					mastery_Module_LightningReflexes.DuplicateApplyChecker = mastery_Module_LightningReflexes.DuplicateApplyChecker + 1;
					mastery_Module_LightningReflexes.CountChecker = mastery_Module_LightningReflexes.CountChecker + 1;
					AddMasteryInvokedEvent(Defender, mastery_Module_LightningReflexes.name, 'FirstHit');
					damageFlag.Module_LightningReflexes = true;
					return true, 'Module_LightningReflexes';
				end
			end
		end
		-- 드라키의 완벽한 비늘
		local mastery_Amulet_Draky_Scale3 = GetMasteryMastered(masteryTable_Defender, 'Amulet_Draky_Scale3');
		if mastery_Amulet_Draky_Scale3 and not GetBuffStatus(Defender, 'Unconscious', 'Or') then
			if mastery_Amulet_Draky_Scale3.DuplicateApplyChecker <= 0 then
				mastery_Amulet_Draky_Scale3.DuplicateApplyChecker = 1;
				AddMasteryInvokedEvent(Defender, mastery_Amulet_Draky_Scale3.name, 'FirstHit');
				return true, mastery_Amulet_Draky_Scale3.name;
			end
		end
		-- 도로리 반향정위
		local mastery_DororiEcholocation = GetMasteryMastered(masteryTable_Defender, 'DororiEcholocation');
		if mastery_DororiEcholocation and not GetBuffStatus(Defender, 'Unconscious', 'Or') and HasBuff(Attacker, mastery_DororiEcholocation.Buff.name) then
			return true, mastery_DororiEcholocation.name;
		end
		-- 무의식
		if HasBuff(Defender, 'UltraInstinct') then
			AddBattleEvent(Defender, 'BuffRevealedFromAbility', {Buff = 'UltraInstinct', EventType = 'FirstHit'});
			return true, 'UltraInstinct';
		end
	end

	-- 엄폐 이동
	if IsLongDistanceAttack(ability) and Defender.Coverable then
		local mastery_MoveWithCover = GetMasteryMastered(masteryTable_Defender, 'MoveWithCover');
		if mastery_MoveWithCover
			and not HasBuff(Defender, 'ExposurePosition')
			and (GetBuff(Defender, 'Conceal') or GetBuff(Defender, 'Conceal_For_Aura')) 
			and GetCoverState(Defender, GetPosition(Attacker), Attacker) ~= 'None' then
			AddMasteryInvokedEvent(Defender, mastery_MoveWithCover.name, 'FirstHit');
			return true, mastery_MoveWithCover.name;
		end
	end

	-- 퇴로
	local mastery_EscapeRoute = GetMasteryMastered(masteryTable_Defender, 'EscapeRoute');
	if mastery_EscapeRoute and not GetBuffStatus(Defender, 'Unconscious', 'Or') and HasBuff(Defender, mastery_EscapeRoute.Buff.name) and mastery_EscapeRoute.CountChecker < 1 then
		AddMasteryInvokedEvent(Defender, mastery_EscapeRoute.name, 'FirstHit');
		mastery_EscapeRoute.CountChecker = mastery_EscapeRoute.CountChecker + 1;
		return true, mastery_EscapeRoute.name;
	end

	-- 모방 회피
	local mastery_ImitationDefence = GetMasteryMastered(masteryTable_Defender, 'ImitationDefence');
	if mastery_ImitationDefence and Defender.TurnState.TurnEnded and not GetBuffStatus(Defender, 'Unconscious', 'Or') and not HasStealthAttackBuff(Attacker) then
		local limit = GetImitationDefenceLimit(Defender, mastery_ImitationDefence, masteryTable_Defender);
		if mastery_ImitationDefence.CountChecker < limit then
			local dmgTypeMap = GetInstantProperty(Defender, mastery_ImitationDefence.name);
			local dmgResult = SafeIndex(dmgTypeMap, 1, ability.SubType) or SafeIndex(dmgTypeMap, 2, ability.HitRateType);
			if dmgResult then
				AddMasteryInvokedEvent(Defender, mastery_ImitationDefence.name, 'FirstHit');
				mastery_ImitationDefence.CountChecker = mastery_ImitationDefence.CountChecker + 1;
				table.insert(actions, Result_BuffPropertyUpdated('Lv', limit - mastery_ImitationDefence.CountChecker, Defender, mastery_ImitationDefence.name, true, true, false, true));
				damageFlag.ImitationDefence = true;
				return true, mastery_ImitationDefence.name;
			end
		end
	end
end
function IsEnableBlock(blockRate, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damageFlag, damage)
	if ability.Type == 'Heal' or ability.IgnoreBlock then
		return false, 'Heal';
	end
	-- 행운 / 공격자
	local buff_Luck = GetBuff(Attacker, 'Luck');
	if buff_Luck then
		return false, buff_Luck.name;
	end
	-- 무조건 치명타 (공격자 특성)
	local isCritical, reason = IsEnableCriticalStrikeChance_Attacker(Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damageFlag);
	-- 들고양이
	local mastery_WildCat = GetMasteryMastered(masteryTable_Defender, 'WildCat');
	if mastery_WildCat and isCritical and ability.Type == 'Attack' and GetRelation(Defender, Attacker) == 'Enemy' then	
		AddMasteryInvokedEvent(Defender, mastery_WildCat.name, 'FirstHit');
		isCritical = false;
	end
	-- 신기루
	local mastery_Mirage = GetMasteryMastered(masteryTable_Defender, 'Mirage');
	if mastery_Mirage and isCritical and ability.Type == 'Attack' and (ability.HitRateType == 'Force' or ability.HitRateType == 'Fall' or ability.HitRateType == 'Throw') then
		AddMasteryInvokedEvent(Defender, mastery_Mirage.name, 'FirstHit');
		isCritical = false;
	end
	if isCritical then
		return false, reason;
	end
	return AbilityBlockRateTest(Attacker, Defender, blockRate, damage);
end
function IsEnableCriticalStrikeChance(criticalStrikeChance, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damageFlag, damage)
	if ability.DamageType == 'Explosion' then
		return false, 'Explosion';
	end
	-- 행운 / 공격자
	local buff_Luck = GetBuff(Attacker, 'Luck');
	if buff_Luck then
		return true, buff_Luck.name;
	end
	-- 무조건 치명타 (공격자 특성)
	local isCritical, reason = IsEnableCriticalStrikeChance_Attacker(Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damageFlag);
	-- 들고양이
	local mastery_WildCat = GetMasteryMastered(masteryTable_Defender, 'WildCat');
	if mastery_WildCat and isCritical and ability.Type == 'Attack' and GetRelation(Defender, Attacker) == 'Enemy' then	
		AddMasteryInvokedEvent(Defender, mastery_WildCat.name, 'FirstHit');
		isCritical = false;
	end
	local mastery_Mirage = GetMasteryMastered(masteryTable_Defender, 'Mirage');
	if mastery_Mirage and isCritical and ability.Type == 'Attack' and (ability.HitRateType == 'Force' or ability.HitRateType == 'Fall' or ability.HitRateType == 'Throw') then
		AddMasteryInvokedEvent(Defender, mastery_Mirage.name, 'FirstHit');
		isCritical = false;
	end
	if isCritical then
		return true, reason;
	end
	return AbilityCriticalStrikeChanceTest(Attacker, Defender, criticalStrikeChance, damage);
end

function IsEnableCriticalStrikeChance_Attacker(Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damageFlag)
	-- 특성 발동으로 인한 무조건 치명타 어빌리티 사용 (ex. 선의 선, 살을 주고 뼈를 취한다.)
	if damageFlag.CriticalHit then
		return true, 'CriticalHit';
	end
	if ability.Type == 'Attack' then
		-- 결정타
		local mastery_FinalBlow = GetMasteryMastered(masteryTable_Attacker, 'FinalBlow');
		if mastery_FinalBlow then
			if Defender.HP < Defender.MaxHP * mastery_FinalBlow.ApplyAmount2/100 then
				AddMasteryInvokedEvent(Attacker, mastery_FinalBlow.name, 'FirstHit');
				return true, mastery_FinalBlow.name;
			end
		end
		-- 특성 그림자 암살
		local mastery_ShadowAssasine = GetMasteryMastered(masteryTable_Attacker, 'ShadowAssasine');
		if mastery_ShadowAssasine and not Attacker.ExposedByEnemy then
			AddMasteryInvokedEvent(Attacker, mastery_ShadowAssasine.name, 'FirstHit');
			return true, mastery_ShadowAssasine.name;
		end
		-- 광전사 - 5 세트
		local mastery_BerserkerSet5 = GetMasteryMastered(masteryTable_Attacker, 'BerserkerSet5');
		if mastery_BerserkerSet5 and HasBuffType(Attacker, nil, nil, mastery_BerserkerSet5.BuffGroup.name, true) then
			if Defender.HP <= Defender.MaxHP * mastery_BerserkerSet5.ApplyAmount / 100 then
				return true, mastery_BerserkerSet5.name;
			end
		end
		-- 해골 가면
		local mastery_Amulet_Munggo_SkullMask = GetMasteryMastered(masteryTable_Attacker, 'Amulet_Munggo_SkullMask');
		if mastery_Amulet_Munggo_SkullMask then
			if ability.Type == 'Attack'
				and ability.HitRateType == 'Melee'
				and Attacker.HP / Attacker.MaxHP * 100 <= mastery_Amulet_Munggo_SkullMask.ApplyAmount
				and mastery_Amulet_Munggo_SkullMask.CountChecker < mastery_Amulet_Munggo_SkullMask.ApplyAmount2 then
				-- damageFlag 체크만, 카운트 증가 & 연출은 GetModifyResultActions_PreState에서 처리
				damageFlag.Amulet_Munggo_SkullMask = true;
				return true, mastery_Amulet_Munggo_SkullMask.name;
			end
		end
	end
	return false;
end
------------------------------------------------------------------------------------------------------------------------
-- 전투 상황으로 인한 이벤트 처리
-------------------------------------------------------------------------------------------------------------------------
function AddBattleResultEventAction(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, resultModifier, isDead, realDamage, damageFlag)
	local buffApplied = {};
	local isHit = defenderState ~= 'Dodge' and (damage <= 0 or realDamage > 0);
	
	-- 1. 기본 어빌리티 컬럼 로직.
	-- 어빌리티 ApplyTargetBuff 로직.
	-- 피격 해야만 걸리는 버프.
	if Defender then
		if isHit then
			local modifier = nil;
			local resultModifier_ApplyBuff = SafeIndex(resultModifier, 'ApplyBuff');
			if resultModifier_ApplyBuff then
				modifier = (resultModifier_ApplyBuff == 'Use') and 100 or 0;
			end
			for _, buffTarget in ipairs({'Buff', 'SubBuff', 'ThirdBuff'}) do
				local buff = GetWithoutError(ability, 'ApplyTarget'..buffTarget);
				local addLv = GetWithoutError(ability, 'ApplyTarget' .. buffTarget .. 'Lv');
				local chance = GetWithoutError(ability, 'ApplyTarget'..buffTarget..'Chance');
				if buff and buff.name and buff.name ~= 'None' and chance > 0 then
					local prob = modifier or chance;
					if RandomTest(prob) then
						InsertBuffActions(actions, Attacker, Defender, buff.name, addLv, true, nil, true, {Type = 'Ability', Value = ability.name}, isDead);
						buffApplied[buff.name] = true;
					end
				end
			end
		end
	end
	-- 피격 해야만 걸리는 ApplyAct값
	if Defender then
		if isHit or ability.Containment then
			local applyRatio = isHit and 1.0 or 0.5;
			if ability.ApplyAct ~= 0 then
				local added, reasons = AddActionApplyAct(actions, Attacker, Defender, ability.ApplyAct * applyRatio, 'Hostile', nil, ability);
				if added then
					AddBattleEvent(Defender, 'AddWait', { Time = ability.ApplyAct * applyRatio });
				end
				ReasonToAddBattleEventMulti(Defender, reasons, 'FirstHit');
			end
		end
	end	
	
	-- 피격 해야만 걸리는 ApplyCost값 (CostBurnRatio 포함)
	if Defender and isHit and IsValidCostType(Defender, ability.ApplyCostType) then
		local applyCost = GetAbilityApplyCost(ability, Attacker, Defender);
		if applyCost ~= 0 and ability.name ~= 'StarArrow' then -- StarArrow 어빌리티는 ABL_STAR_ARROW 함수에서 따로 처리하므로 무시
			local _, reasons = AddActionCost(actions, Defender, applyCost, true);
			AddBattleEvent(Defender, 'AddCostCustomEvent', { CostType = Defender.CostType.name, Count = applyCost, EventType = 'FinalHit' });
			ReasonToAddBattleEventMulti(Defender, reasons, 'FinalHit');
		end	
	end

	-- 3. 일반 특성 이벤트
	-- 0) 공용 이벤트 (피격 or 회피)
	AddBattleResultEventAction_Normal_Common(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender);	
	-- 1) 피격 시 이벤트
	AddBattleResultEventAction_Normal_Hitable(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, realDamage, damageFlag, isDead, buffApplied);	
	-- 2) 회피 시 이벤트
	AddBattleResultEventAction_Normal_Dodge(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, damageFlag);	
	-- 3) 사망 시 이벤트
	if isDead then
		AddBattleResultEventAction_Normal_Dead(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, damageFlag);
	end
	return buffApplied;
end
------------------------------------------------------------------------------------------------------------------------
-- 어빌리티에 의한 모든 이벤트 처리.
-------------------------------------------------------------------------------------------------------------------------
-- 피격 or 회피 시
------------------------------------------------
function AddBattleResultEventAction_Normal_Common(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender)
	-- 방어자가 있어야 하는 로직 구분자.
	if not Defender then
		return;
	end
	
	-- 고지대 저격
	local mastery_HighPositionSniping = GetMasteryMastered(masteryTable_Defender, 'HighPositionSniping');
	if mastery_HighPositionSniping and ability.Type == 'Attack' and GetRelation(Defender, Attacker) == 'Enemy' then
		local distance, height = GetDistanceFromObjectToObjectAbility(ability, Attacker, Defender);
		local attackerHigh, attackerLow = IsAttackerHighPosition(height, ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender);
		if attackerLow then
			local coverState = GetCoverStateForCritical(Defender, masteryTable_Defender, GetPosition(Attacker), Attacker);
			if coverState ~= 'None' then
				mastery_HighPositionSniping.CountChecker = 1;
			end
		end
	end

	-- 특성 예광탄
	local mastery_TracerBullet = GetMasteryMastered(masteryTable_Attacker, 'TracerBullet')
	if mastery_TracerBullet and ability.TargetType == 'Single' and IsGetAbilitySubType(ability, 'Piercing') and ability.HitRateType == 'Force' then
		InsertBuffActions(actions, Attacker, Defender, mastery_TracerBullet.Buff.name, 1, true, nil, true);
		if IsExposedByEnemy(Attacker) then
			InsertBuffActionsModifier(actions, Attacker, Attacker, mastery_TracerBullet.Buff.name, 1, mastery_TracerBullet.Buff.Turn, true, nil, true);
		end
		AddMasteryInvokedEvent(Attacker, mastery_TracerBullet.name, 'Ending');
	end

	-- 몰이 사냥
	local mastery_DriveHunt = GetMasteryMastered(masteryTable_Attacker, 'DriveHunt');
	if mastery_DriveHunt and ability.Type == 'Attack' and GetRelation(Attacker, Defender) == 'Enemy' and HasBuff(Attacker, mastery_DriveHunt.Buff.name) and IsEnableAstonishment(Defender) then
		InsertBuffActions(actions, Attacker, Defender, mastery_DriveHunt.SubBuff.name, addLv, true, nil, true);
		AddMasteryInvokedEvent(Attacker, mastery_DriveHunt.name, 'Ending');
	end
end
-------------------------------------------------------------------------------------------------------------------------
-- 피격 시.
------------------------------------------------
---@param actions table[]
---@param Attacker unit
---@param Defender unit
---@param ability ability
---@param damage number
---@param attackerState "'Critical'"|"'Normal'"
---@param defenderState "'Dodge'"|"'Block'"|"'Hit'"
function AddBattleResultEventAction_Normal_Hitable(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, realDamage, damageFlag, isDead, buffApplied)
	-- 방어자가 있어야 하는 로직 구분자.
	if not Defender then
		return;
	end
	
	-- 회피 하면 동작하지 않는다.
	if defenderState == 'Dodge' or (damage > 0 and GetBuff(Defender, 'StarShield') ~= nil) then
		return;
	end
		
	-- 1.공격 타입
	if ability.Type == 'Attack' and ability.HitRateType == 'Melee' then
		-- 특성. 분쇄
		local mastery_Rend = GetMasteryMastered(masteryTable_Attacker, 'Rend');
		if mastery_Rend then
			local successRate = mastery_Rend.ApplyAmount;
			local addBuffLv = 1;
			-- 전심전력
			local mastery_GreatApplication = GetMasteryMastered(masteryTable_Attacker, 'GreatApplication');
			if mastery_GreatApplication then
				successRate = 100;
			end
			-- 사석위호
			local mastery_StuckArrowheadInStone = GetMasteryMastered(masteryTable_Attacker, 'StuckArrowheadInStone');
			if mastery_StuckArrowheadInStone then
				addBuffLv = addBuffLv + mastery_StuckArrowheadInStone.ApplyAmount2;
			end
			if RandomTest(successRate) then
				InsertBuffActions(actions, Attacker, Defender, mastery_Rend.Buff.name, addBuffLv, true, nil, true, nil, isDead);
				AddMasteryInvokedEvent(Attacker, mastery_Rend.name, 'Ending');
				if mastery_GreatApplication then
					AddMasteryInvokedEvent(Attacker, mastery_GreatApplication.name, 'Ending');
				end
				if mastery_StuckArrowheadInStone then
					AddMasteryInvokedEvent(Attacker, mastery_StuckArrowheadInStone.name, 'Ending');
				end
			end
		end
		-- 특성. 촌경
		local mastery_OneInchPunch = GetMasteryMastered(masteryTable_Attacker, 'OneInchPunch');
		if mastery_OneInchPunch and IsStableAttack(Attacker) then
			-- 절차탁마
			local mastery_Polishing = GetMasteryMastered(masteryTable_Attacker, 'Polishing');
			if mastery_Polishing then
				AddMasteryInvokedEvent(Attacker, mastery_Polishing.name, 'Ending');
				local applyAct = mastery_Polishing.ApplyAmount;
				local added, reasons = AddActionApplyAct(actions, Attacker, Defender, applyAct, 'Hostile', nil, ability);
				if added then
					AddBattleEvent(Defender, 'AddWait', { Time = applyAct });
				end
				ReasonToAddBattleEventMulti(Defender, reasons, 'Ending');
			end
		end
		
		-- 난폭한 트롤 장갑
		local mastery_BattleGlove_Skull = GetMasteryMastered(masteryTable_Attacker, 'BattleGlove_Skull');
		if mastery_BattleGlove_Skull then
			AddMasteryInvokedEvent(Attacker, mastery_BattleGlove_Skull.name, 'Ending');
			local added, reasons = AddActionApplyAct(actions, Attacker, Defender, mastery_BattleGlove_Skull.ApplyAmount, 'Hostile', nil, ability);
			if added then
				AddBattleEvent(Defender, 'AddWait', { Time = mastery_BattleGlove_Skull.ApplyAmount});
			end
			ReasonToAddBattleEventMulti(Attacker, reasons, 'Ending');
		end
	end
	if ability.Type == 'Attack' and ability.HitRateType == 'Force' then
		-- 철갑탄
		local mastery_IronBullet = GetMasteryMastered(masteryTable_Attacker, 'IronBullet');
		if mastery_IronBullet and IsMachineOrHeavyArmor(Defender) then
			local successRate = mastery_IronBullet.ApplyAmount;
			local addBuffLv = 1;
			-- 나는 할 수 있다.
			local mastery_ICanDoIt = GetMasteryMastered(masteryTable_Attacker, 'ICanDoIt');
			if mastery_ICanDoIt then
				successRate = 100;
			end
			if RandomTest(successRate) then
				InsertBuffActions(actions, Attacker, Defender, mastery_IronBullet.Buff.name, addBuffLv, true, nil, true, nil, isDead);
				AddMasteryInvokedEvent(Attacker, mastery_IronBullet.name, 'Ending');
				if mastery_ICanDoIt then
					AddMasteryInvokedEvent(Attacker, mastery_ICanDoIt.name, 'Ending');
				end
			end
		end
	end
	
	-- 2.속성 타입
	-- 1) 물리 속성 공격 일때
	if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Physical') then
	
		-- (1) 공통 
		-- 무기 파괴
		local mastery_WeaponBreaker = GetMasteryMastered(masteryTable_Attacker, 'WeaponBreaker');
		if mastery_WeaponBreaker then
			local applyAmount = mastery_WeaponBreaker.ApplyAmount;
			local addLv = 1;
			-- 무기의 대가
			local mastery_WeaponGrandMaster = GetMasteryMastered(masteryTable_Attacker, 'WeaponGrandMaster');
			if mastery_WeaponGrandMaster then
				applyAmount = 100;
			end
			-- 강력한 무기 파괴
			local mastery_StrongWeaponBreaker = GetMasteryMastered(masteryTable_Attacker, 'StrongWeaponBreaker');
			if mastery_StrongWeaponBreaker then
				addLv = addLv + mastery_StrongWeaponBreaker.ApplyAmount;
			end
			if RandomTest(applyAmount) then
				InsertBuffActions(actions, Attacker, Defender, mastery_WeaponBreaker.Buff.name, addLv, true, nil, true, nil, isDead);
				AddMasteryInvokedEvent(Attacker, mastery_WeaponBreaker.name, 'Ending');
			end
		end
		-- 뼈 부수기
		local mastery_BoneBreaker = GetMasteryMastered(masteryTable_Attacker, 'BoneBreaker');
		if mastery_BoneBreaker then
			local applyAmount = mastery_BoneBreaker.ApplyAmount;
			local addLv = 1;
			-- 거침없는 일격
			local mastery_IndefensibleAttack = GetMasteryMastered(masteryTable_Attacker, 'IndefensibleAttack');
			if mastery_IndefensibleAttack then
				applyAmount = 100;
			end
			-- 치명적인 뼈 부수기
			local mastery_FatalBoneBreaker = GetMasteryMastered(masteryTable_Attacker, 'FatalBoneBreaker');
			if mastery_FatalBoneBreaker then
				addLv = addLv + mastery_FatalBoneBreaker.ApplyAmount;
			end
			if RandomTest(applyAmount) then
				InsertBuffActions(actions, Attacker, Defender, mastery_BoneBreaker.Buff.name, addLv, true, nil, true, nil, isDead);
				AddMasteryInvokedEvent(Attacker, mastery_BoneBreaker.name, 'Ending');
			end
		end
		-- 거침없는 일격
		local mastery_IndefensibleAttack = GetMasteryMastered(masteryTable_Attacker, 'IndefensibleAttack');
		if mastery_IndefensibleAttack and Attacker.AttackPower > Defender.AttackPower then
			InsertBuffActions(actions, Attacker, Defender, mastery_IndefensibleAttack.Buff.name, 1, true, nil, true, nil, isDead);
			AddMasteryInvokedEvent(Attacker, mastery_IndefensibleAttack.name, 'Ending');
		end
		
		-- (2) 타격 속성 공격 일때
		if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Blunt')  then
			--
		end	
		-- (3). 참격 속성 공격 일때
		if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Slashing') then
			-- 특성. 방어구 가르기
			local mastery_BreakArmor = GetMasteryMastered(masteryTable_Attacker, 'BreakArmor');
			if mastery_BreakArmor then
				local applyAmount = mastery_BreakArmor.ApplyAmount;
				-- 특성. 파괴의 검
				local mastery_DestroySword = GetMasteryMastered(masteryTable_Attacker, 'DestroySword');
				if mastery_DestroySword then
					applyAmount = 100;
				end
				if RandomTest(applyAmount) then
					InsertBuffActions(actions, Attacker, Defender, mastery_BreakArmor.Buff.name, 1, true, nil, true, nil, isDead);
					AddMasteryInvokedEvent(Attacker, mastery_BreakArmor.name, 'Ending');
				end
			end
		end
		-- (4). 관통 속성 공격 일때
		if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Piercing') then
			-- 특성. 무기 무력화
			local mastery_BreakWeapon = GetMasteryMastered(masteryTable_Attacker, 'BreakWeapon');
			if mastery_BreakWeapon then
				local applyAmount = mastery_BreakWeapon.ApplyAmount;
				-- 특성. 나는 전설이다
				local mastery_ImLegend = GetMasteryMastered(masteryTable_Attacker, 'ImLegend');
				if mastery_ImLegend then
					applyAmount = 100;
				end
				if RandomTest(applyAmount) then
					InsertBuffActions(actions, Attacker, Defender, mastery_BreakWeapon.Buff.name, 1, true, nil, true, nil, isDead);
					AddMasteryInvokedEvent(Attacker, mastery_BreakWeapon.name, 'Ending');
				end
			end
		end
	end
	
	-- 4). 화염 초능력 공격 시.	
	if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Fire') then
		if attackerState == 'Critical' then
			-- 1) 방화광 : 어빌리티 1 감소.
			local mastery_Pyromaniac = GetMasteryMastered(masteryTable_Attacker, 'Pyromaniac');
			if mastery_Pyromaniac then
				local cooldownAmount = mastery_Pyromaniac.ApplyAmount;
				AddBattleEvent(Attacker, 'Pyromaniac');
				-- 불꽃놀이
				local mastery_Firework = GetMasteryMastered(masteryTable_Attacker, 'Firework');
				if mastery_Firework then
					AddSPPropertyActionsObject(actions, Attacker, mastery_Firework.ApplyAmount);
					AddMasteryInvokedEvent(Attacker, mastery_Firework.name, 'FirstHit');
				end
				--- 열광하는 방화광
				local mastery_EnthusiasticPyromaniac = GetMasteryMastered(masteryTable_Attacker, 'EnthusiasticPyromaniac');
				if mastery_EnthusiasticPyromaniac then
					cooldownAmount = cooldownAmount + mastery_EnthusiasticPyromaniac.ApplyAmount;
				end
				AddAbilityCoolActions(actions, Attacker, -cooldownAmount, function(curAbility)
					return curAbility.SubType == 'Fire';
				end);
			end
			
			--2) 고성능 화염 방사기
			local mastery_Module_FlameBooster = GetMasteryMastered(masteryTable_Attacker, 'Module_FlameBooster');
			if mastery_Module_FlameBooster and HasBuffType(Defender, nil, nil, mastery_Module_FlameBooster.BuffGroup.name, true) then
				InsertBuffActions(actions, Attacker, Defender, mastery_Module_FlameBooster.Buff.name, 1, true, nil, isDead);
				AddMasteryInvokedEvent(Attacker, mastery_Module_FlameBooster.name, 'Ending');
			end
		end
		-- 특성. 타오르는 숨결
		local mastery_BurningBreath = GetMasteryMastered(masteryTable_Attacker, 'BurningBreath');
		if mastery_BurningBreath then
			local applyAmount = mastery_BurningBreath.ApplyAmount
			local addLv = 1;
			-- 특성. 업화
			local mastery_Hellfire = GetMasteryMastered(masteryTable_Attacker, 'Hellfire');
			if mastery_Hellfire then
				applyAmount = 100;
			end
			-- 거침없는 불꽃 숨결
			local mastery_BlazingBreath = GetMasteryMastered(masteryTable_Attacker, 'BlazingBreath');
			if mastery_BlazingBreath then
				addLv = addLv + mastery_BlazingBreath.ApplyAmount3;
			end
			if RandomTest(applyAmount) then
				InsertBuffActions(actions, Attacker, Defender, mastery_BurningBreath.Buff.name, addLv, true, nil, true, nil, isDead);
				AddMasteryInvokedEvent(Attacker, mastery_BurningBreath.name, 'Ending');
			end
		end
	end	
	
	-- 5). 얼음 초능력 공격 시.
	if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Ice') then
		-- 특성. 얼어붙은 숨결
		local mastery_FrozenBreath = GetMasteryMastered(masteryTable_Attacker, 'FrozenBreath');
		if mastery_FrozenBreath then
			local applyAmount = mastery_FrozenBreath.ApplyAmount;
			local addBuffLv = 1;
			-- 얼어붙은 대지
			local mastery_FrozenGround = GetMasteryMastered(masteryTable_Attacker, 'FrozenGround');
			if mastery_FrozenGround then
				applyAmount = 100;
			end
			-- 얼어붙은 마지막 생명의 불꽃
			local mastery_FrozenLastLifeFlame = GetMasteryMastered(masteryTable_Attacker, 'FrozenLastLifeFlame');
			if mastery_FrozenLastLifeFlame then
				addBuffLv = addBuffLv + mastery_FrozenLastLifeFlame.ApplyAmount;
			end
			if RandomTest(applyAmount) then
				InsertBuffActions(actions, Attacker, Defender, mastery_FrozenBreath.Buff.name, addBuffLv, true, nil, true, nil, isDead);
				AddMasteryInvokedEvent(Attacker, mastery_FrozenBreath.name, 'Ending');
			end
		end
		
		if attackerState == 'Critical' then
			-- 고성능 냉각기
			local mastery_Module_FreezingBooster = GetMasteryMastered(masteryTable_Attacker, 'Module_FreezingBooster');
			if mastery_Module_FreezingBooster and HasBuffType(Defender, nil, nil, mastery_Module_FreezingBooster.BuffGroup.name, true) then
				InsertBuffActions(actions, Attacker, Defender, mastery_Module_FreezingBooster.Buff.name, 1, true, nil, isDead);
				AddMasteryInvokedEvent(Attacker, mastery_Module_FreezingBooster.name, 'Ending');
			end
		end
	end
	
	-- 6) 번개 초능력 공격시 
	if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Lightning') then
		-- 특성 벼락
		local mastery_ThunderBolt = GetMasteryMastered(masteryTable_Attacker, 'ThunderBolt');
		if mastery_ThunderBolt then
			local applyAmount = mastery_ThunderBolt.ApplyAmount;
			-- 특성. 거대한 벼락
			local mastery_BigThunderBolt = GetMasteryMastered(masteryTable_Attacker, 'BigThunderBolt');
			if mastery_BigThunderBolt then
				applyAmount = applyAmount + math.floor(GetCurrentSP(Attacker) / mastery_BigThunderBolt.ApplyAmount) * mastery_BigThunderBolt.ApplyAmount2;
			end
			if RandomTest(applyAmount) then
				InsertBuffActions(actions, Attacker, Defender, mastery_ThunderBolt.Buff.name, 1, true, nil, true, nil, isDead);
				AddMasteryInvokedEvent(Attacker, mastery_ThunderBolt.name, 'Ending');
			end
		end
	end
	
	-- 특성. 얼음 파편
	if ability.Type == 'Attack' then
		local mastery_IceFraction = GetMasteryMastered(masteryTable_Attacker, 'IceFraction');
		if mastery_IceFraction and HasBuffType(Defender, 'Debuff', nil, mastery_IceFraction.BuffGroup.name) then
			local addBuff = mastery_IceFraction.Buff.name;
			-- 얼어붙은 검
			local mastery_FrozenSword = GetMasteryMastered(masteryTable_Attacker, 'FrozenSword');
			if mastery_FrozenSword then
				addBuff = mastery_FrozenSword.Buff.name;
			end
			InsertBuffActions(actions, Attacker, Defender, addBuff, 1, true, nil, true, nil, isDead);
			AddMasteryInvokedEvent(Attacker, mastery_IceFraction.name, 'Ending');
		end
	end
	
	-- 흑철 파괴 장갑
	if ability.Type == 'Attack' and ability.HitRateType == 'Melee' then
		-- 확률 디버프
		local mastery_BattleGlove_YellowIronFist = GetMasteryMasteredList(masteryTable_Attacker,
		{
			'BattleGlove_YellowIronFist',
			'BattleGlove_YellowIronFist_Rare',
		});
		if mastery_BattleGlove_YellowIronFist and RandomTest(mastery_BattleGlove_YellowIronFist.ApplyAmount) then
			InsertBuffActions(actions, Attacker, Defender, mastery_BattleGlove_YellowIronFist.Buff.name, 1, true, nil, true, nil, isDead);
			AddMasteryInvokedEvent(Attacker, mastery_BattleGlove_YellowIronFist.name, 'Ending');
		end
		-- 100% 디버프
		local mastery_BattleGlove_YellowIronFist_Epic = GetMasteryMasteredList(masteryTable_Attacker,
		{
			'BattleGlove_YellowIronFist_Ice_Epic',
			'BattleGlove_YellowIronFist_Fire_Epic',
			'BattleGlove_YellowIronFist_Lightning_Epic',
		});
		if mastery_BattleGlove_YellowIronFist_Epic then
			InsertBuffActions(actions, Attacker, Defender, mastery_BattleGlove_YellowIronFist_Epic.Buff.name, 1, true, nil, true, nil, isDead);
			AddMasteryInvokedEvent(Attacker, mastery_BattleGlove_YellowIronFist_Epic.name, 'Ending');
		end
	end
	
	-- 선혈의 야수
	if ability.Type == 'Attack' then
		local mastery_BloodyBeast = GetMasteryMastered(masteryTable_Attacker, 'BloodyBeast');
		if mastery_BloodyBeast and realDamage > 0 and HasBuffType(Defender, nil, nil, mastery_BloodyBeast.BuffGroup.name, true) then
			mastery_BloodyBeast.CountChecker = 1;
		end
	end

	-- 합병증
	if ability.Type == 'Attack' then
		local mastery_Complications = GetMasteryMastered(masteryTable_Attacker, 'Complications');
		if mastery_Complications and realDamage > 0 and HasBuffType(Defender, nil, nil, mastery_Complications.BuffGroup.name, true) then
			mastery_Complications.CountChecker = 1;
		end
	end
	
	-- 위치 선점
	if ability.Type == 'Attack' then
		local mastery_PreoccupyPosition = GetMasteryMastered(masteryTable_Attacker, 'PreoccupyPosition');
		if mastery_PreoccupyPosition and IsEnemy(Attacker, Defender) then
			local _, height = GetDistanceFromObjectToObjectAbility(ability, Attacker, Defender);
			if IsAttackerHighPosition(height, ability, Attacker, Defender, masteryTable_Attacker, masteryTable_Defender) then
				mastery_PreoccupyPosition.CountChecker = 1;
			end
		end
	end
	
	-- 촘촘한 비늘
	local mastery_DenseScale = GetMasteryMastered(masteryTable_Defender, 'DenseScale');
	if mastery_DenseScale and ability.Type == 'Attack' then
		local prevType = GetInstantProperty(Defender, 'DenseScale_LastDamageType');
		if prevType ~= ability.SubType then
			table.insert(actions, Result_UpdateInstantProperty(Defender, 'DenseScale_LastDamageType', ability.SubType, true));
		end
	end
	-- 익숙한 고통
	local mastery_FamiliarSuffering = GetMasteryMastered(masteryTable_Defender, 'FamiliarSuffering');
	if mastery_FamiliarSuffering and ability.Type == 'Attack' then
		local prevType = GetInstantProperty(Defender, 'FamiliarSuffering_LastDamageType');
		if prevType ~= ability.SubType then
			table.insert(actions, Result_UpdateInstantProperty(Defender, 'FamiliarSuffering_LastDamageType', ability.SubType, true));
		end
	end	

	-- 절개
	local mastery_Eviscerate = GetMasteryMastered(masteryTable_Attacker, 'Eviscerate');
	if mastery_Eviscerate and ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Physical') and HasBuffType(Defender, 'Debuff', nil, mastery_Eviscerate.BuffGroup.name) then
		local buffTurn = mastery_Eviscerate.Buff.Turn;
		-- 핏빛 도적
		local mastery_BloodRogue = GetMasteryMastered(masteryTable_Attacker, 'BloodRogue');
		if mastery_BloodRogue then
			buffTurn = buffTurn + mastery_BloodRogue.ApplyAmount2;
		end
		AddMasteryInvokedEvent(Attacker, mastery_Eviscerate.name, 'Ending');
		InsertBuffActionsModifier(actions, Attacker, Defender, mastery_Eviscerate.Buff.name, 1, buffTurn, true, nil, true, nil, isDead);
		-- 핏빛 난도질
		local mastery_BloodySliceAndDice = GetMasteryMastered(masteryTable_Attacker, 'BloodySliceAndDice');
		if mastery_BloodySliceAndDice and (ability.RandomPickCount > 0 or ability.RepeatCount > 0) and not HasBuff(Defender, mastery_BloodySliceAndDice.Buff.name) then
			mastery_BloodySliceAndDice.CountChecker = 1;
		end
	end

	-- 약점 공격
	local mastery_AttackWeakpoint = GetMasteryMastered(masteryTable_Attacker, 'AttackWeakpoint');
	if mastery_AttackWeakpoint and ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Physical') then
		local prob = ability.ApplyAmount;
		local buffTurn = mastery_AttackWeakpoint.Buff.Turn;
		-- 교란 공격
		local mastery_FeintAttack = GetMasteryMastered(masteryTable_Attacker, 'FeintAttack');
		if mastery_FeintAttack then
			prob = 100;
			buffTurn = buffTurn + mastery_FeintAttack.ApplyAmount;
		end
		if RandomTest(prob) then
			AddMasteryInvokedEvent(Attacker, mastery_AttackWeakpoint.name, 'Ending');
			InsertBuffActionsModifier(actions, Attacker, Defender, mastery_AttackWeakpoint.Buff.name, 1, buffTurn, true, nil, true, nil, isDead);
		end
	end

	-- 기본 확률 + 추가특성으로 확정하는 버프 주기 특수화 로직
	local IncrementalProbabilityMasteryBuffApplier = function(baseMastery, certaintyMastery, conditionFunc, buffNamePicker, certaintyMasteryApplyTestFunc)
		local baseMasteryObj = GetMasteryMastered(masteryTable_Attacker, baseMastery);
		if baseMasteryObj and conditionFunc then
			if not conditionFunc(baseMasteryObj) then
				return;
			end
			local prob = baseMasteryObj.ApplyAmount;
			local certaintyMasteryObj = GetMasteryMastered(masteryTable_Attacker, certaintyMastery);
			if certaintyMasteryObj and (not certaintyMasteryApplyTestFunc or certaintyMasteryApplyTestFunc(certaintyMasteryObj)) then
				prob = 100;
			else
				certaintyMasteryObj = nil;
			end
			
			if RandomTest(prob) then
				local buffName, buffReplaceMastery = baseMasteryObj.Buff.name, nil;
				if buffNamePicker then
					local rBuffName, rBuffReplaceMastery = buffNamePicker();
					if rBuffName then
						buffName, buffReplaceMastery = rBuffName, rBuffReplaceMastery;
					end
				end
				if not buffName then
					return;
				end
				AddMasteryInvokedEvent(Attacker, baseMastery, 'Ending');
				if certaintyMasteryObj then
					AddMasteryInvokedEvent(Attacker, certaintyMastery, 'Ending');
				end
				if buffReplaceMastery then
					AddMasteryInvokedEvent(Attacker, buffReplaceMastery, 'Ending');
				end
				InsertBuffActions(actions, Attacker, Defender, buffName, 1, true, nil, true, nil, isDead);
			end
		end
	end;

	-- 혈액 파문, 핏빛샘
	IncrementalProbabilityMasteryBuffApplier('FlowOfBlood', 'BloodWhirlpool', function(m)
		return ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Water');
	end);

	-- 맹독탄, 이것이 마지막이다.
	IncrementalProbabilityMasteryBuffApplier('PoisonBullet', 'ThisIsTheLastTime', function(m)
		return ability.Type == 'Attack' and ability.HitRateType == 'Force';
	end);

	-- 반이능탄, 넌 아무것도 할 수 없다.
	IncrementalProbabilityMasteryBuffApplier('AntiESPBullet', 'YouCanNotDoAnything', function(m)
		return ability.Type == 'Attack' and ability.HitRateType == 'Force';
	end);

	-- 저주 받은 검, 무한검
	IncrementalProbabilityMasteryBuffApplier('CursedSword', 'UnlimitedBlade', function(m)
		return ability.Type == 'Attack' and ability.HitRateType == 'Melee';
	end, function()
		local badBuffList = Linq.new(GetClassList('Buff_Negative'))
			:select(function(pair) return pair[1]; end)
			:toList();
		local buffPicker = RandomBuffPicker.new(Defender, badBuffList);
		return buffPicker:PickBuff();
	end);

	--낙석, 대낙석
	IncrementalProbabilityMasteryBuffApplier('FallingRock', 'BigFallingRock', function(m)
		return ability.Type == 'Attack' and ability.HitRateType == 'Fall' and IsUnprotectedExposureState(Defender);
	end);

	-- 침수, 대홍수, 대폭포
	IncrementalProbabilityMasteryBuffApplier('Flooding', 'Deluge', function(m)
		return ability.Type == 'Attack' and ability.HitRateType == 'Melee';
	end, function()
		local mastery_GreatWaterfall = GetMasteryMastered(masteryTable_Attacker, 'GreatWaterfall');
		if not mastery_GreatWaterfall then
			return nil;
		end
		return mastery_GreatWaterfall.Buff.name, 'GreatWaterfall';
	end);

	-- 영리한 사냥꾼
	local mastery_CleverHunter = GetMasteryMastered(masteryTable_Attacker, 'CleverHunter');
	if mastery_CleverHunter and ability.Type == 'Attack' and IsEnemy(Attacker, Defender) then
		local ratio = mastery_CleverHunter.ApplyAmount;
		local mastery_CleverBeast = GetMasteryMastered(masteryTable_Attacker, 'CleverBeast')
		if mastery_CleverBeast then
			ratio = 100;
		end
		if IsCoverStateNone(Attacker, Defender, masteryTable_Attacker, masteryTable_Defender) and RandomTest(ratio) then
			AddMasteryInvokedEvent(Attacker, mastery_CleverHunter.name, 'Ending');
			if mastery_CleverBeast then
				AddMasteryInvokedEvent(Attacker, mastery_CleverBeast.name, 'Ending');
			end
			InsertBuffActions(actions, Attacker, Defender, mastery_CleverHunter.Buff.name, 1, true, nil, true, nil, isDead);
			mastery_CleverHunter.CountChecker = 1;
		end
	end

	-- 엄폐한 사냥꾼
	local mastery_CoverHunter = GetMasteryMastered(masteryTable_Attacker, 'CoverHunter');
	if mastery_CoverHunter and Attacker.CoveredByEnemy and IsCoverStateNone(Attacker, Defender, masteryTable_Attacker, masteryTable_Defender) then
		damageFlag.CoverHunter = true;
	end

	-- 혁명가 (방어자)
	local mastery_Revolutionist = GetMasteryMastered(masteryTable_Defender, 'Revolutionist');
	if mastery_Revolutionist and IsEnemy(Defender, Attacker) then
		-- 저항 의지
		if Attacker.Lv > Defender.Lv or Attacker.HP > Defender.HP then
			damageFlag.Revolutionist_ResistWill = true
		end
	end
		
	local ConditionalMasteryBuffApplier = function(masteryTable, masteryType, conditionFunc, doFunc, isSubBuff)
		local mastery = GetMasteryMastered(masteryTable, masteryType);
		if mastery and conditionFunc(mastery) then
			local buffName = isSubBuff and mastery.SubBuff.name or mastery.Buff.name;
			InsertBuffActions(actions, Attacker, Defender, buffName, 1, true, nil, true, nil, isDead);
			AddMasteryInvokedEvent(Attacker, mastery.name, 'Ending');
			if doFunc then
				doFunc(mastery);
			end
			return true;
		end
		return false;
	end
	
	if ability.Type == 'Attack' then
		-- 특성. 신경독, 마비독, 산성독, 부식독, 수면독, 독니
		for _, masteryName in ipairs({ 'Neurotoxin', 'ParalysisPoison', 'AcidPoison', 'CorrosionPoison', 'SleepPoison', 'VenomFang' }) do
			ConditionalMasteryBuffApplier(masteryTable_Attacker, masteryName, function(m) return attackerState == 'Critical' end);
		end
		-- AddBuffByCriticalHit
		for _, mastery in pairs(masteryTable_Attacker) do
			if mastery.AddBuffByCriticalHit then
				ConditionalMasteryBuffApplier(masteryTable_Attacker, mastery.name, function(m) return attackerState == 'Critical' end);
			end
		end

		-- 특성 산성 점액
		local DoHandlerForAcidMucus = function(m)
			-- 점액 분비
			local mastery_SecretionOfMucus = GetMasteryMastered(masteryTable_Attacker, 'SecretionOfMucus');
			if mastery_SecretionOfMucus then
				AddMasteryInvokedEvent(Attacker, mastery_SecretionOfMucus.name, 'Ending');
				local applyAct = -1 * mastery_SecretionOfMucus.ApplyAmount;
				local added, reasons = AddActionApplyAct(actions, Attacker, Attacker, applyAct, 'Friendly', nil, ability);
				if added then
					AddBattleEvent(Attacker, 'AddWait', { Time = applyAct });
				end
				ReasonToAddBattleEventMulti(Attacker, reasons, 'Ending');
			end
		end;
		local AcidMucusApplied = ConditionalMasteryBuffApplier(masteryTable_Attacker, 'AcidMucus', function(m) return attackerState == 'Critical' end, DoHandlerForAcidMucus);
		-- 점액 투하
		if not AcidMucusApplied and ability.HitRateType == 'Fall' then
			ConditionalMasteryBuffApplier(masteryTable_Attacker, 'NeguriDrop', function(m) return true end, DoHandlerForAcidMucus);
		end
		-- 특성 강력한 주포
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'StrongCannon', function(m) return attackerState == 'Critical' end);
		-- 특성 커다란 이빨
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'BigFang', function(m) return ability.HitRateType == 'Melee' end);
		-- 특성 더러운 숨결
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'DirtyBreath', function(m) return ability.HitRateType == 'Force' end);
		-- 특성 맹독 괴수
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'PoisonMonster', function(m) return attackerState == 'Critical' and HasBuffType(Defender, 'Debuff', nil, m.BuffGroup.name) end);
		-- 특성 노련한 전사
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'ExpertWarrior', function(m) return Attacker.AttackPower > Defender.AttackPower end);
		-- 특성 물에 독타기
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'PoisonedWater', function(m) return IsGetAbilitySubType(ability, 'Water'); end);
		-- 땅의 검
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'EarthSword', function(m) return ability.SubType == 'Slashing' end);

		-- 특성 예광탄
		local mastery_TracerBullet = GetMasteryMastered(masteryTable_Attacker, 'TracerBullet')
		if mastery_TracerBullet and ability.TargetType == 'Single' and IsGetAbilitySubType(ability, 'Piercing') and ability.HitRateType == 'Force' then
			InsertBuffActionsModifier(actions, Attacker, Defender, mastery_TracerBullet.SubBuff.name, 1, mastery_TracerBullet.Buff.Turn, true, nil, true, nil, isDead);
		end
		-- 그림자 습격
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'ShadowAttack', function(m) return attackerState == 'Critical' and not Attacker.ExposedByEnemy end);

		-- 돌주먹
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'StoneFist', function(m) 	
			return IsUnprotectedExposureState(Defender) and attackerState == 'Critical';
		end);

		-- 꿰뚫는 탄환
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'UnavoidableBullet', function(m) 	
			return IsGetAbilitySubType(ability, 'Piercing');
		end);

		-- 바위 망치 (바위 주먹)
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'StoneHammer', function(m) 	
			return IsGetAbilitySubType(ability, 'Physical');
		end);

		-- 강화된 라이플
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'Module_Rifle', function(m) 	
			return attackerState == 'Critical' and SafeIndex(Attacker, 'Weapon', 'Type', 'name') == 'OuterDevice_Rifle';
		end);

		-- 침묵의 사격
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'SilencingShot', function(m) 	
			return ability.HitRateType == 'Force';
		end);

		-- 독 바르기: XXX
		for _, buffName in ipairs({ 'Envenoming_WoundPoison', 'Envenoming_Poison', 'Envenoming_AcidicPoison', 'Envenoming_Neurotoxin', 'Envenoming_CorrosionPoison' }) do
			local buff_Envenoming = GetBuff(Attacker, buffName);
			if buff_Envenoming and IsGetAbilitySubType(ability, 'Physical') then
				local isInvoked = false;
				-- 독 바르기: 상처감염 독
				if buffName == 'Envenoming_WoundPoison' then
					local buffList = GetClassList('Buff');
					local testBuffGroup = {'Bleeding', 'Bruise'};
					isInvoked = HasBuffType(Defender, 'Debuff', nil, testBuffGroup) or table.exist(buffApplied, function(applied, buffName)
						return applied and table.find(testBuffGroup, SafeIndex(buffList, buffName, 'Group')) ~= nil;
					end);
				else
					isInvoked = RandomTest(buff_Envenoming.ApplyAmount);
				end
				if isInvoked then
					InsertBuffActions(actions, Attacker, Defender, buff_Envenoming.AddBuff, 1, true, nil, true, nil, isDead);
					buff_Envenoming.DuplicateApplyChecker = 1;
				end
			end
		end

		-- 만독
		if ability.HitRateType == 'Melee' then
			local mastery_AllPoison = GetMasteryMastered(masteryTable_Attacker, 'AllPoison');
			if mastery_AllPoison then
				local poisonBuffList = Linq.new(GetClassList('Buff_Poison'))
				:select(function(pair) return pair[1]; end)
				:toList();
				
				local buffPicker = RandomBuffPicker.new(Defender, poisonBuffList);
		
				InsertBuffActions(actions, Attacker, Defender, buffPicker:PickBuff(), 1, true);
				AddMasteryInvokedEvent(Attacker, 'AllPoison', 'Ending');
			end
		end

		-- 흑철 불꽃검
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'Sword_BlackIron_Fire_Epic', function(m) 	
			return attackerState == 'Critical';
		end);

		-- 흑철 서리검
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'Sword_BlackIron_Ice_Epic', function(m) 	
			return attackerState == 'Critical';
		end);

		-- 흑철 폭풍검
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'Sword_BlackIron_Wind_Epic', function(m) 	
			return attackerState == 'Critical';
		end);

		-- 뱀 권총
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'Pistol_Serpent_Legend', function(m) 	
			return ability.HitRateType == 'Force' and ability.TargetType == 'Single' and IsGetAbilitySubType(ability, 'Piercing');
		end);

		-- 이끼 낀 송곳니
		local mastery_Amulet_Tima_Pascal = GetMasteryMastered(masteryTable_Attacker, 'Amulet_Tima_Pascal');
		if mastery_Amulet_Tima_Pascal and ability.HitRateType == 'Melee' then
			local buffName = mastery_Amulet_Tima_Pascal.Buff.name;
			if HasBuff(Defender, mastery_Amulet_Tima_Pascal.Buff.name) then
				buffName = mastery_Amulet_Tima_Pascal.SubBuff.name;
			end
			InsertBuffActions(actions, Attacker, Defender, buffName, 1, true, nil, true, nil, isDead);
			AddMasteryInvokedEvent(Attacker, mastery_Amulet_Tima_Pascal.name, 'Ending');
		end

		-- 고드름 창
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'IciclesMissile', function(m)
			if not IsGetAbilitySubType(ability, m.Type.name) then
				return false;
			end
			local buff = GetBuff(Attacker, m.Buff.name);
			return buff and buff.Lv >= buff:MaxStack(Attacker);
		end, nil, true);

		-- 고전압
		ConditionalMasteryBuffApplier(masteryTable_Attacker, 'HighVoltage', function(m)
			local testRatio = m.ApplyAmount;
			-- 승압
			local mastery_RaiseVoltage = GetMasteryMastered(masteryTable_Attacker, 'RaiseVoltage');
			if mastery_RaiseVoltage then
				testRatio = mastery_RaiseVoltage.ApplyAmount2;
			end
			return realDamage >= Defender.MaxHP * testRatio / 100;
		end);
	end
end
-------------------------------------------------------------------------------------------------------------------------
-- 회피 시.
------------------------------------------------
function AddBattleResultEventAction_Normal_Dodge(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, damageFlag)
	-- 방어자가 있어야 하는 로직 구분자.
	if not Defender then
		return;
	end
	
	-- 회피 안하면 동작하지 않는다.
	if defenderState ~= 'Dodge' then
		return;
	end
	
	-- 0). 일반 공격.
	-- 1). 타격 속성 공격 일때
	-- 2). 참격 속성 공격 일때
	-- 3). 관통 속성 공격 일때
	if ability.Type == 'Attack' and IsGetAbilitySubType(ability, 'Piercing') and ability.HitRateType == 'Force' then
		-- 특성. 우연한 적중
		local mastery_LuckyShot = GetMasteryMastered(masteryTable_Attacker, 'LuckyShot');
		if mastery_LuckyShot then
			if RandomTest(mastery_LuckyShot.ApplyAmount) then
				local addBuff = mastery_LuckyShot.Buff.name;
				AddMasteryInvokedEvent(Attacker, mastery_LuckyShot.name, 'Ending');
				-- 우연은 필연
				local mastery_DoubleLuckyShot = GetMasteryMastered(masteryTable_Attacker, 'DoubleLuckyShot');
				if mastery_DoubleLuckyShot then
					addBuff = mastery_DoubleLuckyShot.SubBuff.name;
					AddMasteryInvokedEvent(Attacker, mastery_DoubleLuckyShot.name, 'Ending');
				end
				InsertBuffActions(actions, Attacker, Defender, addBuff, 1, true, nil, true);
			end
		end	
	end

	-- 엄폐한 암살자
	local mastery_CoverAssassin = GetMasteryMastered(masteryTable_Defender, 'CoverAssassin');
	if mastery_CoverAssassin and IsEnemy(Defender, Attacker) and GetCoverStateForCritical(Defender, masteryTable_Defender, GetPosition(Attacker), Attacker) ~= 'None' then
		mastery_CoverAssassin.CountChecker = 1;
	end

	-- 신속한 모방 회피
	local mastery_CleverImitationDefence = GetMasteryMastered(masteryTable_Defender, 'CleverImitationDefence');
	if mastery_CleverImitationDefence and SafeIndex(damageFlag, 'ImitationDefence') then
		local applyAct = -mastery_CleverImitationDefence.ApplyAmount3;
		local added, reasons = AddActionApplyAct(actions, Defender, Defender, applyAct, 'Friendly', true, ability);
		if added then
			AddBattleEvent(Defender, 'AddWait', { Time = applyAct });
		end
		ReasonToAddBattleEventMulti(Defender, reasons, 'Ending');
	end
end
---------------------------------------------
-- 사망 시
---------------------------------------------
function AddBattleResultEventAction_Normal_Dead(actions, Attacker, Defender, ability, damage, attackerState, defenderState, masteryTable_Attacker, masteryTable_Defender, damageFlag)
	-- 명군사
	local mastery_GreatMilitaryAffairs = GetMasteryMastered(masteryTable_Attacker, 'GreatMilitaryAffairs');
	if mastery_GreatMilitaryAffairs then
		local group_debuff_List = GetBuffType(Defender, 'Debuff', nil, mastery_GreatMilitaryAffairs.BuffGroup.name);
		if #group_debuff_List > 0 or Defender.PreBattleState then
			mastery_GreatMilitaryAffairs.CountChecker = 1;
		end
	end
	-- 연계된 화공, 연계된 뇌공
	for _, testMasteryName in ipairs({ 'ChainFireTactics', 'ChainLightningTactics' }) do
		local testMastery = GetMasteryMastered(masteryTable_Attacker, testMasteryName);
		if testMastery and HasBuff(Defender, testMastery.Buff.name) then
			testMastery.CountChecker = 1;
		end
	end
	-- 달빛사냥꾼
	local mastery_MoonHunter = GetMasteryMastered(masteryTable_Attacker, 'MoonHunter');
	if mastery_MoonHunter and IsDarkTime(GetMission(Attacker).MissionTime.name) then
		local group_debuff_List = GetBuffType(Defender, 'Debuff', nil, mastery_MoonHunter.BuffGroup.name);
		if #group_debuff_List > 0 or Defender.PreBattleState then
			mastery_MoonHunter.DuplicateApplyChecker = 1;
		else
			mastery_MoonHunter.DuplicateApplyChecker = 0;
		end
	end
	-- 기습 훈련
	local mastery_AmbushTraining = GetMasteryMastered(masteryTable_Attacker, 'AmbushTraining');
	if mastery_AmbushTraining then
		local group_debuff_List = GetBuffType(Defender, 'Debuff', nil, mastery_AmbushTraining.BuffGroup.name);
		if #group_debuff_List > 0 or Defender.PreBattleState then
			mastery_AmbushTraining.CountChecker = 1;
			local ambushingKillList = GetInstantProperty(Attacker, 'AmbushingKillList') or {};
			if not table.find(ambushingKillList, Defender) then
				table.insert(ambushingKillList, Defender);
			end
			SetInstantProperty(Attacker, 'AmbushingKillList', ambushingKillList);
		end
	end

	-- 이중 극독
	local mastery_VenomExplosion = GetMasteryMastered(masteryTable_Attacker, 'VenomExplosion');
	if mastery_VenomExplosion then
		local debuffList = GetBuffType(Defender, 'Debuff', nil, mastery_VenomExplosion.BuffGroup.name);
		if #debuffList > 0 then
			mastery_VenomExplosion.CountChecker = 1;
			local killList = GetInstantProperty(Attacker, 'VenomExplosionKillList') or {};
			if not table.find(killList, Defender) then
				table.insert(killList, Defender);
			end
			SetInstantProperty(Attacker, 'VenomExplosionKillList', killList);
			SetInstantProperty(Defender, 'VenomExplosionPoisonList', table.map(debuffList, function(b) return b.name end));
		end
	end
	-- 선혈의 미치광이
	local mastery_BloodSwordBerserker = GetMasteryMastered(masteryTable_Attacker, 'BloodSwordBerserker');
	if mastery_BloodSwordBerserker and HasBuffType(Defender, 'Debuff', nil, mastery_BloodSwordBerserker.BuffGroup.name) then
		mastery_BloodSwordBerserker.CountChecker = 1;
	end
	-- 선혈의 괴수
	local mastery_BloodyMonster = GetMasteryMastered(masteryTable_Attacker, 'BloodyMonster');
	if mastery_BloodyMonster and HasBuffType(Defender, 'Debuff', nil, mastery_BloodyMonster.BuffGroup.name) then
		mastery_BloodyMonster.CountChecker = 1;
	end
	-- 지배자
	local mastery_Overlord = GetMasteryMastered(masteryTable_Attacker, 'Overlord');
	if mastery_Overlord and IsEnemy(Attacker, Defender) then
		local allyList = GetTargetInRangeSight(Attacker, 'Sight', 'Team', true);
		local enemyList = GetTargetInRangeSight(Attacker, 'Sight', 'Enemy', true);
		if #enemyList > #allyList then
			mastery_Overlord.CountChecker = 1;
		end
		-- 우월감
		if Attacker.Lv > Defender.Lv or Attacker.HP > Defender.HP then
			damageFlag.Overlord_Superiority = true;
		end
	end
	
	-- 얼어붙은 영혼 수확자
	local mastery_FrozenReaper = GetMasteryMastered(masteryTable_Attacker, 'FrozenReaper');
	if mastery_FrozenReaper then
		if IsEnemy(Attacker, Defender) and HasBuff(Defender, mastery_FrozenReaper.Buff.name) then
			mastery_FrozenReaper.CountChecker = 1;
		end
	end
	
	-- 붉은 송곳니
	local mastery_Amulet_Dorori_Fang_Red = GetMasteryMastered(masteryTable_Attacker, 'Amulet_Dorori_Fang_Red');
	if mastery_Amulet_Dorori_Fang_Red and HasBuffType(Defender, nil, nil, mastery_Amulet_Dorori_Fang_Red.BuffGroup.name, true) then
		mastery_Amulet_Dorori_Fang_Red.CountChecker = 1;
	end

	-- 은밀한 처리
	local mastery_StealthyKill = GetMasteryMastered(masteryTable_Attacker, 'StealthyKill');
	if mastery_StealthyKill and HasBuff(Attacker, mastery_StealthyKill.Buff.name) and (Defender.PreBattleState or HasBuffType(Defender, nil, nil, mastery_StealthyKill.BuffGroup.name)) then
		mastery_StealthyKill.CountChecker = 1;
	end

	-- 혁명가 (공격자)
	local mastery_Revolutionist = GetMasteryMastered(masteryTable_Attacker, 'Revolutionist');
	if mastery_Revolutionist and IsEnemy(Attacker, Defender) then
		-- 모험가
		if Attacker.Lv < Defender.Lv or Attacker.HP < Defender.HP then
			damageFlag.Revolutionist_Challenger = true;
		end
		-- 우월감
		if Attacker.Lv > Defender.Lv or Attacker.HP > Defender.HP then
			damageFlag.Revolutionist_Superiority = true;
		end
	end
end
-------------------------------------------------------------------------------------------------------
-- 전투 결과값 Battle Damage modify.  피해량 변화.
-------------------------------------------------------------------------------------------------------
function GetModifyResultActions_PreState(actions, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage, attackerState, defenderState, knockbackPower, damageFlag, abilityDetailInfo, resultModifier, missionTime)
	-- 이능력 중화 장갑
	if IsGetAbilitySubType(ability, 'ESP') and attackerState == 'Critical' and GetMasteryMastered(masteryTable_Defender, 'Module_ESPArmor') then
		attackerState = 'Normal';
	end
	-- 오색 가죽
	if IsGetAbilitySubType(ability, 'ESP') and attackerState == 'Critical' and GetMasteryMastered(masteryTable_Defender, 'FiveColorSkin') then
		attackerState = 'Normal';
	end
	-- 단단한 허물
	local mastery_HeavyMoltAfterDeath = GetMasteryMastered(masteryTable_Defender, 'HeavyMoltAfterDeath');
	if mastery_HeavyMoltAfterDeath and attackerState == 'Critical' and HasBuff(Defender, mastery_HeavyMoltAfterDeath.SubBuff.name) then
		attackerState = 'Normal';
		AddBattleEvent(Defender, 'MasteryInvokedCustomEvent', { Mastery = mastery_HeavyMoltAfterDeath.name, EventType = 'FinalHit' });
	end	
	-- 밤안개
	local mastery_NightSmoke = GetMasteryMastered(masteryTable_Defender, 'NightSmoke');
	if mastery_NightSmoke and attackerState == 'Critical' and IsDarkTime(missionTime) and HasBuff(Defender, mastery_NightSmoke.Buff.name) then
		attackerState = 'Normal';
		AddBattleEvent(Defender, 'MasteryInvokedCustomEvent', { Mastery = mastery_NightSmoke.name, EventType = 'FinalHit' });
	end	
	----------------------------------------------------------------------------
	-- 모든 공격 방어 처리.
	----------------------------------------------------------------------------
	if defenderState ~= 'Block' and defenderState ~= 'Dodge' then
		-- 예측된 위험
		local mastery_CalculatedRisk = GetMasteryMastered(masteryTable_Defender, 'CalculatedRisk');
		if mastery_CalculatedRisk and defenderState ~= 'Block' and ability.HitRateType == 'Melee' and SafeIndex(resultModifier, 'ReactionAbility') then
			defenderState = 'Block';
			mastery_CalculatedRisk.CountChecker = 1;
			AddBattleEvent(Defender, 'MasteryInvokedCustomEvent', { Mastery = mastery_CalculatedRisk.name, EventType = 'FinalHit' });
		end	
		-- 완전 방어
		---@cast Attacker unit
		local buff_PerfectDefence = GetBuff(Defender, 'PerfectDefence');
		if buff_PerfectDefence and defenderState ~= 'Block' and not Attacker.Cloaking then
			local testUnits = {};
			-- 자신
			table.insert(testUnits, Defender);
			-- 소환한 기계들 (제어권 뺏긴 기계 제외) + 탈취한 기계들
			table.append(testUnits, GetMachineListUnderControl(Defender));
			for _, testUnit in ipairs(testUnits) do
				if IsInSight(testUnit, Attacker, true) then
					defenderState = 'Block';
					AddBattleEvent(Defender, 'BuffInvokedFromAbility', { Buff = buff_PerfectDefence.name, EventType = 'FinalHit' });
					break;
				end
			end
		end
		-- 최후의 저항
		local mastery_LastStand = GetMasteryMastered(masteryTable_Defender, 'LastStand');
		if mastery_LastStand and defenderState ~= 'Block' and Defender.HP / Defender.MaxHP * 100 <= mastery_LastStand.ApplyAmount then
			defenderState = 'Block';
			AddBattleEvent(Defender, 'LastStand');
		end
	end

	local damAdd = 0;
	local damMul = 0;
	----------------------------------------------------------------------------
	-- 피해량 조정부 : 해당 구문 이후 피해량 조정부를 뒤로 붙이지 말자. 계산 값이 달라진다.
	----------------------------------------------------------------------------	
	if defenderState ~= 'Dodge' then
		-- 특성. 헤드샷 HeadShot
		local headshotRatio = GetHeadshotRateCalculator(Attacker, Defender, ability, abilityDetailInfo);
		if headshotRatio > 0 then
			if DoNothingAITest(Defender) then
				headshotRatio = 100;
			end
			if RandomTest(headshotRatio) then
				AddBattleEvent(Attacker, 'HeadShot');
				local isImmuned, reason = IsHeadshotImmuned(Defender);
				if not isImmuned then
					damMul = damMul + (GetClassList('Mastery').HeadShot.ApplyAmount2 - 1) * 100;
				else
					AddBattleEvent(Defender, 'HeadShotImmuned', { Reason = reason[1] });
				end
			end
		end

		-- 특성 마력 폭발
		local mastery_SpellExplosion = GetMasteryMastered(masteryTable_Attacker, 'SpellExplosion');
		if mastery_SpellExplosion then
			local spellPower = GetBuff(Attacker, mastery_SpellExplosion.Buff.name);
			if spellPower then
				local activeChance = spellPower.Lv * mastery_SpellExplosion.ApplyAmount;
				if RandomTest(activeChance) then
					damMul = damMul + mastery_SpellExplosion.ApplyAmount2;
					spellPower.DuplicateApplyChecker = 1;
					AddMasteryInvokedEvent(Attacker, mastery_SpellExplosion.name, 'FirstHit');
				end
			end
		end
	end
	damage = damage * (1 + damMul / 100) + damAdd;
	
	-- 연쇄 효과 : 혼절
	if attackerState == 'Critical' and defenderState ~= 'Dodge' and ability.SubType == 'Lightning'
		and IsObjectOnFieldEffectBuffAffector(Defender, {'Water', 'ContaminatedWater'}) and Set.new({'Human', 'Beast'})[Defender.Race.name] then
		AddActionChainEventOccured(actions, Attacker, Defender, 'Faint', ability);
	end
	-- 연쇄 효과 : 누전
	if attackerState == 'Critical' and defenderState ~= 'Dodge' and ability.SubType == 'Water'
		and IsObjectOnFieldEffectBuffAffector(Defender, {'Spark'}) and Set.new({'Human', 'Beast'})[Defender.Race.name] then
		AddActionChainEventOccured(actions, Attacker, Defender, 'ElectricLeakage', ability);
	end
	-- 연쇄 효과 : 균열
	if attackerState == 'Critical' and defenderState ~= 'Dodge' and ability.SubType == 'Ice'
		and IsObjectOnFieldEffectBuffAffector(Defender, {'Lava'}) then
		AddActionChainEventOccured(actions, Attacker, Defender, 'Fracture', ability);
	end

	-- 해골 가면
	local mastery_Amulet_Munggo_SkullMask = GetMasteryMastered(masteryTable_Attacker, 'Amulet_Munggo_SkullMask');
	if mastery_Amulet_Munggo_SkullMask and SafeIndex(damageFlag, 'Amulet_Munggo_SkullMask') then
		-- 카운트 증가 & 연출
		AddMasteryInvokedEvent(Attacker, mastery_Amulet_Munggo_SkullMask.name, 'FirstHit');
		mastery_Amulet_Munggo_SkullMask.CountChecker = mastery_Amulet_Munggo_SkullMask.CountChecker + 1;
	end

	return damage, attackerState, defenderState, knockbackPower;
end
function GetModifyResultActions_Final(actions, Attacker, Defender, ability, phase, masteryTable_Attacker, masteryTable_Defender, damage, attackerState, defenderState, knockbackPower, damageFlag)
	-- 공격받으면 무조건 사망 피해를 입습니다. DeadSign
	local buff_DeadSign = GetBuff(Defender, 'DeadSign');
	if buff_DeadSign then
		attackerState = 'Critical';
		defenderState = 'Hit';
		knockbackPower = 0;
		if damage < Defender.HP then
			damage = Defender.HP;
		end
		return damage, attackerState, defenderState, knockbackPower;
	end

	-- 최종 결과를 바꾸는 것이기에 특성 체크보단 일단 원하는 결과 상태 체크부터 하자.	
	local initDamage = damage;
	if ability.Type == 'Heal' then
		return damage, attackerState, defenderState, knockbackPower;
	end	
	if not Defender then
		return damage, attackerState, defenderState, knockbackPower;
	end

	----------------------------------------------------------------------------
	-- 피해량 조정부 : 해당 구문 이후 피해량 조정부를 뒤로 붙이지 말자. 계산 값이 달라진다.
	----------------------------------------------------------------------------		
	-- 순서에 따라 결과가 달라지니 고려할 것이기에

	if defenderState ~= 'Dodge' then
		-- 특성 불살. DoNotKill
		local mastery_DoNotKill = GetMasteryMastered(masteryTable_Attacker, 'DoNotKill');
		if mastery_DoNotKill then
			if Defender.HP > mastery_DoNotKill.ApplyAmount then
				local curHP = Defender.HP - damage;
				if curHP < mastery_DoNotKill.ApplyAmount  then
					damage = Defender.HP - mastery_DoNotKill.ApplyAmount;
				end
				AddBattleEvent(Attacker, 'DoNotKill');
			end			
		end
		----------------------------------------------------------------------------
		-- 아래부터 방어자 피해량 증감, 공격자 피해량 증감 다처리하고 칩시다. 
		----------------------------------------------------------------------------
		-- 특성 얼음가죽. IceSkin
		local mastery_IceSkin = GetMasteryMastered(masteryTable_Defender, 'IceSkin');
		if mastery_IceSkin then
			if ability.Type == 'Attack' and ability.SubType == 'Ice' then
				damage = damage * mastery_IceSkin.ApplyAmount/100;
				AddBattleEvent(Defender, 'IceSkin');
				-- 혹한의 괴수
				local mastery_ColdMonster = GetMasteryMastered(masteryTable_Defender, 'ColdMonster');
				if mastery_ColdMonster then
					mastery_ColdMonster.CountChecker = 1;
				end
			end
		end	
		-- 특성 용암 가죽. LavaSkin
		local mastery_LavaSkin = GetMasteryMastered(masteryTable_Defender, 'LavaSkin');
		if mastery_LavaSkin then
			if ability.Type == 'Attack' and ability.SubType == 'Fire' then
				damage = damage * mastery_LavaSkin.ApplyAmount/100;
				AddBattleEvent(Defender, 'LavaSkin');
				-- 폭염의 괴수
				local mastery_HotMonster = GetMasteryMastered(masteryTable_Defender, 'HotMonster');
				if mastery_HotMonster then
					mastery_HotMonster.CountChecker = 1;
				end
			end
		end		
		-- 특성 번개 가죽. LightningSkin
		local mastery_LightningSkin = GetMasteryMastered(masteryTable_Defender, 'LightningSkin');
		if mastery_LightningSkin then
			if ability.Type == 'Attack' and ability.SubType == 'Lightning' then
				damage = damage * mastery_LightningSkin.ApplyAmount/100;
				AddBattleEvent(Defender, 'LightningSkin');
				-- 빗속의 괴수
				local mastery_RainMonster = GetMasteryMastered(masteryTable_Defender, 'RainMonster');
				if mastery_RainMonster then
					mastery_RainMonster.CountChecker = 1;
				end
			end
		end
		-- 특성 달빛 가죽. MoonSkin
		local mastery_MoonSkin = GetMasteryMastered(masteryTable_Defender, 'MoonSkin');
		if mastery_MoonSkin then
			if ability.Type == 'Attack' and ability.SubType == 'Earth' then
				damage = damage * mastery_MoonSkin.ApplyAmount/100;
				AddMasteryInvokedEvent(Defender, mastery_MoonSkin.name, 'FirstHit');
				-- 달빛의 괴수
				local mastery_MoonMonster = GetMasteryMastered(masteryTable_Defender, 'MoonMonster');
				if mastery_MoonMonster then
					mastery_MoonMonster.CountChecker = 1;
				end
			end
		end
		-- 특성 내화성. Module_FireResistance
		local mastery_Module_FireResistance = GetMasteryMastered(masteryTable_Defender, 'Module_FireResistance');
		if mastery_Module_FireResistance then
			if ability.Type == 'Attack' and ability.SubType == 'Fire' then
				local applyAmount = mastery_Module_FireResistance.ApplyAmount;
				if Defender.Info.name == 'Drone_Sprinkler' then
					applyAmount = applyAmount + mastery_Module_FireResistance.ApplyAmount2;
				end
				damage = damage * ( 100 - applyAmount ) / 100;
				AddBattleEvent(Defender, 'Module_FireResistance');
			end
		end
		-- 특성 내한성. Module_FireResistance
		local mastery_Module_IceResistance = GetMasteryMastered(masteryTable_Defender, 'Module_IceResistance');
		if mastery_Module_IceResistance then
			if ability.Type == 'Attack' and ability.SubType == 'Ice' then
				local applyAmount = mastery_Module_IceResistance.ApplyAmount;
				if Defender.Info.name == 'Drone_Sprinkler' then
					applyAmount = applyAmount + mastery_Module_IceResistance.ApplyAmount2;
				end
				damage = damage * ( 100 - applyAmount ) / 100;
				AddBattleEvent(Defender, 'Module_IceResistance');
			end
		end
		-- 특성 절연성. Module_Insulation
		local mastery_Module_Insulation = GetMasteryMastered(masteryTable_Defender, 'Module_Insulation');
		if mastery_Module_Insulation then
			if ability.Type == 'Attack' and ability.SubType == 'Lightning' then
				local applyAmount = mastery_Module_Insulation.ApplyAmount;
				if Defender.Info.name == 'Drone_Sprinkler' then
					applyAmount = applyAmount + mastery_Module_Insulation.ApplyAmount2;
				end
				damage = damage * ( 100 - applyAmount ) / 100;
				AddBattleEvent(Defender, 'Module_Insulation');
			end
		end
		-- 특성 내수성. Module_WaterResistance
		local mastery_Module_WaterResistance = GetMasteryMastered(masteryTable_Defender, 'Module_WaterResistance');
		if mastery_Module_WaterResistance then
			if ability.Type == 'Attack' and ability.SubType == 'Water' then
				local applyAmount = mastery_Module_WaterResistance.ApplyAmount;
				if Defender.Info.name == 'Drone_Sprinkler' then
					applyAmount = applyAmount + mastery_Module_WaterResistance.ApplyAmount2;
				end
				damage = damage * ( 100 - applyAmount ) / 100;
				AddBattleEvent(Defender, 'Module_WaterResistance');
			end
		end
		-- 특성 내풍성. Module_WaterResistance
		local mastery_Module_WindResistance = GetMasteryMastered(masteryTable_Defender, 'Module_WindResistance');
		if mastery_Module_WindResistance then
			if ability.Type == 'Attack' and ability.SubType == 'Wind' then
				local applyAmount = mastery_Module_WindResistance.ApplyAmount;
				if Defender.Info.name == 'Drone_Sprinkler' then
					applyAmount = applyAmount + mastery_Module_WindResistance.ApplyAmount2;
				end
				damage = damage * ( 100 - applyAmount ) / 100;
				AddMasteryInvokedEvent(Defender, mastery_Module_WindResistance.name, 'FirstHit');
			end
		end
		-- 특성 중장비. HeavyEquipment
		local mastery_HeavyEquipment = GetMasteryMastered(masteryTable_Defender, 'HeavyEquipment');
		if mastery_HeavyEquipment then
			if ability.Type == 'Attack' and ability.SubType == 'Wind' then
				damage = damage * ( 100 - mastery_HeavyEquipment.ApplyAmount)/100;
				if knockbackPower == 0 then
					AddBattleEvent(Defender, 'HeavyEquipment');
				end
			end
		end
		------------------------------------------------------------------------
		-- 피해량 보정의 경우, 충격장이 제일 마지막에 있어야한다.
		-- 순서를 고려하시오. 앞에꺼 실행됨으로 인해 뒤에꺼 적용안되는 걸 피하세요.
		-- 현재 순서 : 마력장 -> 강철 심장 -> 충격장 -> 충격흡수
		------------------------------------------------------------------------
		-- 특성 무기 받아치기. WeaponParry
		local mastery_WeaponParry = GetMasteryMastered(masteryTable_Defender, 'WeaponParry');
		if mastery_WeaponParry then
			if IsMeleeDistanceAbility(Attacker, Defender) and damage < Defender.AttackPower then
				damage = math.ceil(damage * (1 - mastery_WeaponParry.ApplyAmount/100));
				damageFlag.WeaponParry = true;
				AddMasteryInvokedEvent(Defender, mastery_WeaponParry.name, 'FirstHit');
				mastery_WeaponParry.CountChecker = 1;
			end
		end
		-- 칠흑의 에트로스 성전사 장갑
		local mastery_BattleGlove_EtrosFist_Legend = GetMasteryMastered(masteryTable_Defender, 'BattleGlove_EtrosFist_Legend');
		if mastery_BattleGlove_EtrosFist_Legend then
			if IsGetAbilitySubType(ability, 'Physical') and damage < Defender.AttackPower then
				damage = math.ceil(damage * (1 - mastery_BattleGlove_EtrosFist_Legend.ApplyAmount/100));
				AddMasteryInvokedEvent(Defender, mastery_BattleGlove_EtrosFist_Legend.name, 'FirstHit');
			end
		end
		-- 특성 마력장. MagicField
		local mastery_MagicField = GetMasteryMastered(masteryTable_Defender, 'MagicField');
		if mastery_MagicField and IsGetAbilitySubType(ability, 'ESP') and damage < Defender.ESPPower then
			damage = damage * mastery_MagicField.ApplyAmount / 100;
			damageFlag.MagicField = true;
			AddMasteryInvokedEvent(Defender, mastery_MagicField.name, 'FirstHit');
		end
		-- 특성 바위성. RockCastle
		local mastery_RockCastle = GetMasteryMastered(masteryTable_Defender, 'RockCastle');
		if mastery_RockCastle and IsGetAbilitySubType(ability, 'Physical') and damage < Defender.Armor then
			damage = damage * mastery_RockCastle.ApplyAmount / 100;
			damageFlag.RockCastle = true;
			AddMasteryInvokedEvent(Defender, mastery_RockCastle.name, 'FirstHit');
		end
		-- 특성 얼음성. IceCastle
		local mastery_IceCastle = GetMasteryMastered(masteryTable_Defender, 'IceCastle');
		if mastery_IceCastle and IsGetAbilitySubType(ability, 'ESP') and damage < Defender.Resistance then
			damage = damage * mastery_IceCastle.ApplyAmount / 100;
			damageFlag.IceCastle = true;
			AddMasteryInvokedEvent(Defender, mastery_IceCastle.name, 'FirstHit');
		end
		-- 특성 마력 보호막
		local mastery_MagicArmor = GetMasteryMastered(masteryTable_Defender, 'MagicArmor');
		if mastery_MagicArmor and damage > Defender.MaxCost and Defender.Cost >= mastery_MagicArmor.ApplyAmount2 then
			local applyAmount = mastery_MagicArmor.ApplyAmount;
			damage = math.ceil(damage * (1 - applyAmount / 100));
			damageFlag.MagicArmor = true;
			AddMasteryInvokedEvent(Defender, mastery_MagicArmor.name, 'FirstHit');
		end
		-- 특성 강철 심장. IronHeart
		local mastery_IronHeart = GetMasteryMastered(masteryTable_Defender, 'IronHeart');
		if mastery_IronHeart then
			local limitedHP = Defender.MaxHP * mastery_IronHeart.ApplyAmount/100;
			if damage <= limitedHP then
				damage = damage * mastery_IronHeart.ApplyAmount2/100;
				damageFlag.IronHeart = true;
				AddMasteryInvokedEvent(Defender, mastery_IronHeart.name, 'FirstHit');
			end
		end
		-- 특수 장갑
		local mastery_Module_HardArmor = GetMasteryMastered(masteryTable_Defender, 'Module_HardArmor');
		if mastery_Module_HardArmor and Defender.Cost >= mastery_Module_HardArmor.ApplyAmount3 then
			local limitedHP = Defender.MaxHP * mastery_Module_HardArmor.ApplyAmount/100;
			if damage <= limitedHP then
				damage = damage * mastery_Module_HardArmor.ApplyAmount2/100;
				damageFlag.Module_HardArmor = true;
				AddMasteryInvokedEvent(Defender, mastery_Module_HardArmor.name, 'FirstHit');
			end
		end
		-- 장비 반짝이는 충격 보호대. Amulet_AniDamage 
		local mastery_Amulet_AniDamage = GetMasteryMastered(masteryTable_Defender, 'Amulet_AniDamage');
		if mastery_Amulet_AniDamage then
			local limitedHP = math.ceil(Defender.MaxHP * mastery_Amulet_AniDamage.ApplyAmount/100);
			if damage > limitedHP and Defender.HP > limitedHP and mastery_Amulet_AniDamage.DuplicateApplyChecker < mastery_Amulet_AniDamage.ApplyAmount2 then
				damage = limitedHP;
				damageFlag.Amulet_AniDamage = true;
				mastery_Amulet_AniDamage.DuplicateApplyChecker = mastery_Amulet_AniDamage.DuplicateApplyChecker + 1;
				AddMasteryInvokedEvent(Defender, mastery_Amulet_AniDamage.name, 'FirstHit');
			end
		end
		-- 특성 충격장. ImpulseFields 
		local mastery_ImpulseFields = GetMasteryMastered(masteryTable_Defender, 'ImpulseFields');
		if mastery_ImpulseFields then
			local limitedHP = math.ceil(Defender.MaxHP * mastery_ImpulseFields.ApplyAmount/100);
			if damage > limitedHP and Defender.HP > limitedHP then
				damage = limitedHP;
				damageFlag.ImpulseFields = true;
				AddMasteryInvokedEvent(Defender, mastery_ImpulseFields.name, 'FirstHit');
			end
		end
		-- 특성 지원 모듈 - 충격흡수. Module_ShockAbsorber 
		local mastery_Module_ShockAbsorber = GetMasteryMastered(masteryTable_Defender, 'Module_ShockAbsorber');
		if mastery_Module_ShockAbsorber and not HasBuff(Defender, mastery_Module_ShockAbsorber.Buff.name) then
			local limitedHP = math.ceil(Defender.MaxHP * mastery_Module_ShockAbsorber.ApplyAmount/100);
			if damage > limitedHP and Defender.Cost >= mastery_Module_ShockAbsorber.ApplyAmount2 then
				damage = limitedHP;
				damageFlag.Module_ShockAbsorber = true;
				AddMasteryInvokedEvent(Defender, mastery_Module_ShockAbsorber.name, 'FirstHit');
			end
		end
		-- 버프 그림자 환영
		local buff_ShdowIllusion = GetBuff(Defender, 'ShdowIllusion');
		if buff_ShdowIllusion and damage >= Defender.HP then
			if damage >= Defender.HP then
				damage = 0;
				defenderState = 'Dodge';
				if buff_ShdowIllusion.DuplicateApplyChecker == 0 then
					damageFlag.ShdowIllusion = true;
				end
				buff_ShdowIllusion.DuplicateApplyChecker = buff_ShdowIllusion.DuplicateApplyChecker + 1;
			end
		end
	end
	----------------------------------------------------------------------------
	-- 넉백 처리
	----------------------------------------------------------------------------
	-- 특성. 바람 망치
	if IsGetAbilitySubType(ability, 'Wind') and defenderState ~= 'Dodge' then
		local mastery_WindHammer = GetMasteryMastered(masteryTable_Attacker, 'WindHammer');
		if mastery_WindHammer then			
			knockbackPower = knockbackPower + 1;
			AddBattleEvent(Attacker, 'WindHammer');
		end
	end		
	-- 특성. 꽉쥔 주먹
	if ability.Type == 'Attack' and ability.HitRateType == 'Melee' and defenderState ~= 'Dodge' then
		local mastery_ClenchedFist = GetMasteryMastered(masteryTable_Attacker, 'ClenchedFist');
		if mastery_ClenchedFist then
			knockbackPower = knockbackPower + 1;
			AddMasteryInvokedEvent(Attacker, mastery_ClenchedFist.name, 'FinalHit');
		end
	end
	-- 버프(지형효과). 빙판
	if defenderState ~= 'Dodge' and knockbackPower > 0 then
		local buff_Ice = GetBuff(Defender, 'Ice');
		if buff_Ice then
			knockbackPower = knockbackPower + buff_Ice.ApplyAmount;
			AddBattleEvent(Defender, 'BuffInvokedFromAbility', { Buff = buff_Ice.name, EventType = 'FinalHit', NoEffect = true});
		end
	end
	-- 장비. 광전사 대검
	if ability.Type == 'Attack' and ability.HitRateType == 'Melee' and defenderState ~= 'Dodge' then
		local mastery_TwoHandSword_Berserker_Set = GetMasteryMastered(masteryTable_Attacker, 'TwoHandSword_Berserker_Set');
		if mastery_TwoHandSword_Berserker_Set then
			knockbackPower = knockbackPower + mastery_TwoHandSword_Berserker_Set.ApplyAmount;
			AddMasteryInvokedEvent(Attacker, mastery_TwoHandSword_Berserker_Set.name, 'FinalHit');
		end
	end

	-- 장비. 붉은모래 손도끼
	if ability.Type == 'Attack' and ability.HitRateType == 'Melee' and defenderState ~= 'Dodge' then
		local mastery_Axe_RedSand_Legend = GetMasteryMastered(masteryTable_Attacker, 'Axe_RedSand_Legend');
		if mastery_Axe_RedSand_Legend then
			knockbackPower = knockbackPower + mastery_Axe_RedSand_Legend.ApplyAmount;
			AddMasteryInvokedEvent(Attacker, mastery_Axe_RedSand_Legend.name, 'FinalHit');
		end
	end
	
	-- 넉백 면역 처리
	if defenderState ~= 'Dodge' and knockbackPower > 0 then
		-- 육중함 우선 처리 (세트 효과가 있으므로)
		local masteryImuneKB = GetMasteryMastered(masteryTable_Defender, 'Heaviness');
		-- 육중함이 없으면 아무거나
		if not masteryImuneKB then
			for _, mastery in pairs(masteryTable_Defender) do
				if mastery.DisableKnockback then
					masteryImuneKB = mastery;
					break;
				end
			end
		end
		if masteryImuneKB then
			knockbackPower = 0;
			AddMasteryInvokedEvent(Defender, masteryImuneKB.name, 'FinalHit');
			if masteryImuneKB.name == 'Heaviness' then
				-- 산
				local mastery_Mountain = GetMasteryMastered(masteryTable_Defender, 'Mountain');
				if mastery_Mountain then
					AddMasteryInvokedEvent(Defender, mastery_Mountain.name, 'FinalHit');
					mastery_Mountain.CountChecker = 1;
					-- 실제 효과는 이벤트 핸들러에서 처리됨
				end
				-- 육중한 비늘
				local mastery_HeavyScale = GetMasteryMastered(masteryTable_Defender, 'HeavyScale');
				if mastery_HeavyScale then
					AddMasteryInvokedEvent(Defender, mastery_HeavyScale.name, 'FinalHit');
					mastery_HeavyScale.CountChecker = 1;
					-- 실제 효과는 이벤트 핸들러에서 처리됨
				end
			end
		end
	end
	-- 버프. 고치
	if defenderState ~= 'Dodge' and knockbackPower > 0 then
		local buff_CocoonWeb = GetBuff(Defender, 'CocoonWeb');
		if buff_CocoonWeb then
			knockbackPower = 0;
			AddBattleEvent(Defender, 'BuffInvokedFromAbility', { Buff = buff_CocoonWeb.name, EventType = 'FinalHit', NoEffect = true});
		end
	end
	return damage, attackerState, defenderState, knockbackPower;
end
-----------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------
-- 턴 시작 : 전투 턴 액션 함수.
---------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
function UpdateBattleTurnStartActions(actions, owner, ds)
	if owner.CostType.name == 'Vigor' then
		-- 자신의 코스트 회복 관련.
		local curCost = owner.RegenCost + GetConditionalStatus(owner, 'RegenCost', {}, {MissionTemperature = GetMission(owner).Temperature.name});
		if curCost ~= 0 then
			local _, reasons = AddActionCost(actions, owner, curCost, true);
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		end
	elseif owner.CostType.name == 'Rage' then
		if HasBuffType(owner, nil, nil, 'Rage') then
			-- 자신의 코스트 회복 관련.
			local curCost = owner.RegenCost + GetConditionalStatus(owner, 'RegenCost', {}, {MissionTemperature = GetMission(owner).Temperature.name});
			if curCost ~= 0 then
				local _, reasons = AddActionCost(actions, owner, curCost, true);
				ReasonToUpdateBattleEventMulti(owner, ds, reasons);
			end
		end
	elseif owner.CostType.name == 'Fuel' then
		local fuelChange = -owner.RegenCost - GetConditionalStatus(owner, 'RegenCost', {}, {MissionTemperature = GetMission(owner).Temperature.name});
		local retCost, reasons = AddActionCost(actions, owner, fuelChange, true);
		local realAddValue = retCost - owner.Cost;
		if realAddValue ~= 0 then
			ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = realAddValue });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
end
---------------------------------------------------------------------------------------------------
-- 피해를 입을 시 : 공용 버프(State) 이벤트 핸들러.
---------------------------------------------------------------------------------------------------
function UpdateBattleTakeDamageActions(actions, owner, ds)
	-- 자신의 코스트 회복 관련.
	if owner.CostType.name == 'Rage' then
		if owner.Cost < owner.MaxCost and owner.RegenCost > 0 then
			local curCost = owner.RegenCost;
			local _, reasons = AddActionCost(actions, owner, curCost, true);
			ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = curCost });
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		end
	end
end
---------------------------------------------------------------------------------------------------
-- 피해를 줄 시 : 공용 버프(State) 이벤트 핸들러.
---------------------------------------------------------------------------------------------------
function UpdateBattleGiveDamageActions(actions, owner)
end
-------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
-- 액션 정리 구문.
-------------------------------------------------------------------------------------
-- 체력 회복 구문.
function AddActionRestoreHP(actions, user, target, amount, damageType)
	local lostHP  = target.MaxHP - target.HP;
	
	local reasons = {};
	local masteryTable = GetMastery(target);
	
	local multiplier = 0;
	-- 생존 본능
	local mastery_InstinctForSurvival = GetMasteryMastered(masteryTable, 'InstinctForSurvival');
	if mastery_InstinctForSurvival then
		multiplier = multiplier + mastery_InstinctForSurvival.ApplyAmount;
		table.insert(reasons, MakeMasteryStatInfo(mastery_InstinctForSurvival.name, nil));
	end
	-- 무장연금 가죽 자켓
	local mastery_Jacket_BattleAlchemist_Set = GetMasteryMastered(masteryTable, 'Jacket_BattleAlchemist_Set');
	if mastery_Jacket_BattleAlchemist_Set then
		multiplier = multiplier + mastery_Jacket_BattleAlchemist_Set.ApplyAmount;
		table.insert(reasons, MakeMasteryStatInfo(mastery_Jacket_BattleAlchemist_Set.name, nil));
	end

	-- 복원의 불꽃
	local mastery_RecoverFire = GetMasteryMastered(masteryTable, 'RecoverFire');
	if mastery_RecoverFire and target.Overcharge > 0 then
		multiplier = multiplier + mastery_RecoverFire.ApplyAmount5;
		table.insert(reasons, MakeMasteryStatInfo(mastery_RecoverFire.name, nil));
	end
	-- 자가 수리
	local mastery_Module_SelfRepair = GetMasteryMastered(masteryTable, 'Module_SelfRepair');
	if mastery_Module_SelfRepair then
		multiplier = multiplier + mastery_Module_SelfRepair.ApplyAmount;
		table.insert(reasons, MakeMasteryStatInfo(mastery_Module_SelfRepair.name, nil));
	end

	amount = amount * (1 + multiplier / 100);
	if amount > lostHP then
		amount = lostHP;
	end
	
	local damReturn = Result_Damage(-1 * math.floor(amount), 'Normal', 'Heal', user, target, damageType or 'Heal');
	damReturn.sequential = true;
	table.insert(actions, damReturn);
	return amount, reasons;
end
function AddActionCost(actions, target, amount, sequential, updateStatus, ignoreModifier)
	local reasons = {};
	local multiplier = 0;
	if not ignoreModifier and target.CostType.name == 'Vigor' then
		-- 감염 / 부패
		local buff = GetBuff(target, 'Infection') or GetBuff(target, 'Infection_Heavy');
		---@cast buff class_Buff
		if buff and amount > 0 then
			multiplier = multiplier - buff.ApplyAmount;
		end
	elseif not ignoreModifier and target.CostType.name == 'Fuel' then
		-- 고급 연료
		local mastery_Module_GoodEnergy = GetMasteryMastered(GetMastery(target), 'Module_GoodEnergy');
		if mastery_Module_GoodEnergy and amount < 0 then
			local applyAmount = mastery_Module_GoodEnergy.ApplyAmount;
			if target.Info.name == 'Drone_Transport' then
				applyAmount = applyAmount + mastery_Module_GoodEnergy.ApplyAmount2;
			end
			multiplier = multiplier - applyAmount;
			table.insert(reasons, MakeMasteryStatInfo(mastery_Module_GoodEnergy.name, nil));
			-- 연비 강화 프로그램
			local mastery_Module_FuelEnhancement = GetMasteryMastered(GetMastery(target), 'Module_FuelEnhancement');
			if mastery_Module_FuelEnhancement then
				multiplier = multiplier - mastery_Module_FuelEnhancement.ApplyAmount;
				table.insert(reasons, MakeMasteryStatInfo(mastery_Module_FuelEnhancement.name, nil));
			end
		end
		-- 구동 호환성 - 고속
		if target.Info.name == 'Drone_Speed' and amount < 0 then
			local mastery_DrivingDevice_HoverSpeed_Epic = GetMasteryMasteredList(GetMastery(target), {'DrivingDevice_HoverSpeed_Epic', 'DrivingDevice_HoverSpeed_Legend'});
			if mastery_DrivingDevice_HoverSpeed_Epic then
				multiplier = multiplier - mastery_DrivingDevice_HoverSpeed_Epic.ApplyAmount;
				table.insert(reasons, MakeMasteryStatInfo(mastery_DrivingDevice_HoverSpeed_Epic.name, nil));
			end
		end
		-- 연료 호환성 - 수송
		if target.Info.name == 'Drone_Transport' and amount < 0 then
			local mastery_Fuel_TransportList = { 'Fuel_Industrial_Middle', 'Fuel_Industrial_Big' };
			for _, value in pairs (mastery_Fuel_TransportList) do
				local mastery_Fuel_Transport = GetMasteryMastered(GetMastery(target), value);
				if mastery_Fuel_Transport then
					multiplier = multiplier - mastery_Fuel_Transport.ApplyAmount;
					table.insert(reasons, MakeMasteryStatInfo(mastery_Fuel_Transport.name, nil));
				end
			end
		end
		-- 과열
		local buff_Overdrive = GetBuff(target, 'Overdrive');
		if buff_Overdrive and amount < 0 then
			multiplier = multiplier + buff_Overdrive.ApplyAmount;
			table.insert(reasons, {Type = buff_Overdrive.name, Value = nil, ValueType = 'Buff'});
		end
		-- 광학 위장
		local buff_ActiveCamouflage = GetBuff(target, 'ActiveCamouflage');
		if buff_ActiveCamouflage and amount < 0 then
			multiplier = multiplier + buff_ActiveCamouflage.ApplyAmount;
			table.insert(reasons, {Type = buff_ActiveCamouflage.name, Value = nil, ValueType = 'Buff'});
		end
	end
	multiplier = math.max(-100, multiplier);
	amount = amount * (1 + multiplier / 100);
	
	local totalAomunt = math.floor(target.Cost + amount);
	local result = math.max(0, math.min(totalAomunt, target.MaxCost));
	if target.Cost == result then
		return result;
	end
	if updateStatus == nil then
		updateStatus = true;
	end
	local prop = {};
	prop.type = 'PropertyUpdated';
	prop.target = target;
	prop.property_key = 'Cost';
	prop.property_value = tostring(result);
	prop.update_status = updateStatus;
	prop.sequential = sequential == nil and false or sequential;
	table.insert(actions, prop);
	local addAmount = result - target.Cost;
	table.insert(actions, Result_FireWorldEvent('ActionCostAdded', {Unit=target, AddAmount=addAmount}, target));
	return result, reasons;
end
function AddOvercharge(actions, target, amount, sequential)
	local totalAmount = target.Overcharge + amount;
	local result = math.max(0, totalAmount);
    local prop = Result_PropertyUpdated('Overcharge', result, target, false, sequential);
	table.insert(actions, prop);
	local prop2 = nil;
	if result > target.MaxOverchargeDuration then
		prop2 = Result_PropertyUpdated('MaxOverchargeDuration', result, target, false, sequential);
		table.insert(actions, prop2);
	elseif result <= 0 and target.MaxOverchargeDuration ~= target.OverchargeDuration then
		prop2 = Result_PropertyUpdated('MaxOverchargeDuration', target.OverchargeDuration, target, false, sequential);
		table.insert(actions, prop2);
	end
	return prop, prop2;
end
function AddSP(actions, target, amount, sequential)
	local totalAomunt = target.SP + amount;
	local result = math.max(0, math.min(totalAomunt, target.MaxSP));
	local prop = Result_PropertyUpdated('SP', result, target, false, sequential);
	table.insert(actions, prop);
	return prop;
end
function UpdateAbilityPropertyActions(actions, target, abilityName, propName, propValue)
	table.insert(actions, Result_AbilityPropertyUpdated(propName, propValue, target, abilityName, true));
end
function AddAbilityUseCountActions(actions, target, ability, value, invokeEvent)
	if not ability.IsUseCount or not ability.AutoUseCount then
		return;
	end
	local newUseCount = math.clamp(ability.UseCount + value, 0, ability.MaxUseCount);
	if newUseCount == ability.UseCount then
		return;
	end
	UpdateAbilityPropertyActions(actions, target, ability.name, 'UseCount', newUseCount);
	if invokeEvent then
		local realAddAmount = newUseCount - ability.UseCount;
		table.insert(actions, Result_FireWorldEvent('AbilityUseCountRestored', {Unit = target, Ability = ability, AddAmount = realAddAmount}, target));
	end
end
function UpdateAbilityCoolActions(actions, target, value, ifFunc)
	-- [MOD] 预热：免疫敌方施加的技能冷却增加/禁用技能效果
	local warmupImmune = GetBuff(target, 'WarmUp') ~= nil;
	local abilityList = GetAllAbility(target, false, true);
	for index, ability in ipairs(abilityList) do
		-- Cool 값이 다른 경우만
		if ability.Cool ~= value and (not ifFunc or ifFunc(ability)) then
			if warmupImmune and value > ability.Cool then
				-- 预热持有者免疫「把冷却调大」的负面效果
			else
				UpdateAbilityPropertyActions(actions, target, ability.name, 'Cool', value);
			end
		end
	end
end
---@param actions table
---@param target unit
---@param addValue number
---@param ifFunc? fun(a:class_Ability):boolean|nil
function AddAbilityCoolActions(actions, target, addValue, ifFunc)
	-- [MOD] 预热：免疫敌方施加的技能冷却增加/禁用技能效果
	local warmupImmune = GetBuff(target, 'WarmUp') ~= nil;
	local abilityList = GetAllAbility(target, false, true);
	for index, ability in ipairs(abilityList) do
		-- Cool 증가는 무조건, Cool 감소는 현재 Cool 값이 0 보다 큰 경우만
		if (addValue > 0 or ability.Cool > 0) and (not ifFunc or ifFunc(ability)) then
			if warmupImmune and addValue > 0 then
				-- 预热持有者免疫「技能CD+N」的负面效果
			else
				UpdateAbilityPropertyActions(actions, target, ability.name, 'Cool', ability.Cool + addValue);
			end
		end
	end
end
function AddActionRestoreActions(actions, self)
	-- 이미 행동력이 최대라서 더 회복할 게 없다.
	if not self.TurnState.Moved and not self.TurnState.UsedMainAbility then
		return;
	end
	-- 행동력이 하나도 없는 상황에서만 ExtraActable로 변경, 아니면 행동력 2개가 되도록 턴 상태 초기화
	if self.TurnState.UsedMainAbility and not self.TurnState.ExtraActable then
		table.insert(actions, Result_PropertyUpdated('TurnState/ExtraActable', true, self));
	else
		table.append(actions, {GetInitializeTurnActions(self, true)});
	end
	table.insert(actions, Result_FireWorldEvent('ActionPointRestored', {Unit = self}, self));
	AddUnitStats(self, 'ActionRestore', 1);
end
function AddActionRestoreFullActions(actions, self)
	-- 이미 행동력이 최대라서 더 회복할 게 없다.
	if not self.TurnState.Moved and not self.TurnState.UsedMainAbility then
		return;
	end
	table.append(actions, {GetInitializeTurnActions(self, true)});
	table.insert(actions, Result_FireWorldEvent('ActionPointRestored', {Unit = self}, self));
	AddUnitStats(self, 'ActionRestore', 1);
end
-----------------------------------------------------------------------------------
-- 최종 어빌리티 피해량, 적용량 Modify
-------------------------------------------------------------------------------------
function ResultModifier_Damage(amount, resultModifier)
	local result = amount;
	if resultModifier.DamageAdjust then
		if resultModifier.DamageAdjust == 'Use' then
			result = resultModifier.Damage;
		end
	end
	return result;
end
-----------------------------------------------------------------------------------
-- 메세지 처리 함수
-------------------------------------------------------------------------------------
function AddBattleEvent(obj, eventType, args)
	local events = GetInstantProperty(obj, 'BattleEvents') or {};
	if not args then
		table.insert(events, eventType);
	else
		local eventInst = table.deepcopy(args);
		eventInst.Type = eventType;
		table.insert(events, eventInst);
	end
	SetInstantProperty(obj, 'BattleEvents', events);
end
-----------------------------------------------------------------------------------
-- 메세지 처리 함수 유틸리티
-------------------------------------------------------------------------------------
function AddMasteryInvokedEvent(obj, masteryName, directingEvent, worldEvent)
	local events = GetInstantProperty(obj, 'BattleEvents') or {};
	local eventInst = { Type = 'MasteryInvokedCustomEvent', Mastery = masteryName, EventType = directingEvent, MissionChat = true, WorldEventType = worldEvent or '' };
	for _, event in ipairs(events) do
		if event.Type == 'MasteryInvokedCustomEvent' and event.Mastery == masteryName then
			return;
		end
	end
	table.insert(events, eventInst);
	SetInstantProperty(obj, 'BattleEvents', events);
end
----------------------------------------------------------------
-- 초능력 프로퍼티 증감하는 함수.
----------------------------------------------------------------
function AddSPPropertyActions(actions, target, properetyType, amount, isStatusUpdate, ds, sequential, noEvent)
	if not target.ESP or not target.ESP.name or target.ESP.name ~= properetyType then
		return;
	end

	local multiplier = 0;
	local masteryTable = GetMastery(target);
	-- 강화 엔진 UE4 - 과열
	local mastery_PowerDevice_EA10_Overdrive = GetMasteryMasteredList(masteryTable, {'PowerDevice_EA10_Overdrive', 'PowerDevice_EA20_Overdrive'});
	if mastery_PowerDevice_EA10_Overdrive and amount > 0 and target.ESP.name == 'Heat' then
		multiplier = multiplier + mastery_PowerDevice_EA10_Overdrive.ApplyAmount;
	end
	-- 강화 엔진 UE4 - 고속
	local mastery_PowerDevice_EA10_Speed = GetMasteryMasteredList(masteryTable, {'PowerDevice_EA10_Speed', 'PowerDevice_EA20_Speed'});
	if mastery_PowerDevice_EA10_Speed and amount > 0 and target.Info.name == 'Drone_Speed' then
		multiplier = multiplier + mastery_PowerDevice_EA10_Speed.ApplyAmount;
	end
	-- 최고급 강화 센서 - 정보
	local mastery_Sensor_EnhancedInfo_Epic = GetMasteryMasteredList(masteryTable, {'Sensor_EnhancedInfo_Epic', 'Sensor_EnhancedInfo_Legend'});
	if mastery_Sensor_EnhancedInfo_Epic and amount > 0 and target.ESP.name == 'Info' then
		multiplier = multiplier + mastery_Sensor_EnhancedInfo_Epic.ApplyAmount;
	end
	-- 최고급 강화 센서 - 수색
	local mastery_Sensor_EnhancedSearch_Epic = GetMasteryMasteredList(masteryTable, {'Sensor_EnhancedSearch_Epic', 'Sensor_EnhancedSearch_Legend'});
	if mastery_Sensor_EnhancedSearch_Epic and amount > 0 and target.ESP.name == 'Info' then
		multiplier = multiplier + mastery_Sensor_EnhancedSearch_Epic.ApplyAmount;
	end
	-- 엔진 가속기
	local mastery_Module_AddSP = GetMasteryMastered(masteryTable, 'Module_AddSP');
	if mastery_Module_AddSP and amount > 0 then
		local applyAmount = mastery_Module_AddSP.ApplyAmount;
		if target.ESP and target.ESP.name == 'Heat' then
			applyAmount = applyAmount + mastery_Module_AddSP.ApplyAmount2;
		end
		multiplier = multiplier + applyAmount;
	end
	-- 오버부스팅
	local mastery_Module_Overboosting = GetMasteryMastered(masteryTable, 'Module_Overboosting');
	if mastery_Module_Overboosting and amount > 0 then
		multiplier = multiplier + mastery_Module_Overboosting.ApplyAmount;
	end
	-- 한계를 뚫어라
	local mastery_DrillLimit = GetMasteryMastered(masteryTable, 'DrillLimit');
	if mastery_DrillLimit and amount > 0 then
		multiplier = multiplier + mastery_DrillLimit.ApplyAmount;
	end
	amount = math.floor(amount * (1 + multiplier / 100));
	
	local curValue = target.SP;
	local maxValue = target.MaxSP;
	local updateAmount = math.min(maxValue, math.max(0, curValue + amount));
	table.insert(actions, Result_PropertyUpdated('PrevSP', curValue, target, false, sequential));
	if updateAmount == maxValue and target.Overcharge == 0 then
		-- 과충전 상태가 되는 로직은 턴 획득 시로 옮겨감
	elseif amount < 0 and target.Overcharge > 0 then
		table.insert(actions, Result_PropertyUpdated('Overcharge', 0, target, false, sequential));
		-- UI 게이지 표시를 위한 MaxOverchargeDuration 값 초기화
		if target.MaxOverchargeDuration ~= target.OverchargeDuration then
			table.insert(actions, Result_PropertyUpdated('MaxOverchargeDuration', target.OverchargeDuration, target, false, sequential));
		end
	end
	table.insert(actions, Result_PropertyUpdated('SP', updateAmount, target, isStatusUpdate, sequential));
	-- 연출은 최소, 최대치 제한과 상관없이 보여준다.
	if amount ~= 0 and not noEvent then
		local battleEventArg = {Count = amount, SpType = target.ESP.name};
		if ds then
			ds:UpdateBattleEvent(GetObjKey(target), 'AddSp', battleEventArg);
		else
			AddBattleEvent(target, 'AddSp', battleEventArg);
		end
	end
	
	if amount < 0 and target.Overcharge > 0 and not noEvent then
		table.insert(actions, Result_FireWorldEvent('OverchargeEnded', {Unit=target}, target));
	end

	-- 특성 넘쳐 흐르는 에너지
	local mastery_AccelerationEnergy = GetMasteryMastered(masteryTable, 'AccelerationEnergy');
	if mastery_AccelerationEnergy and amount > 0 and target.Overcharge > 0 and not noEvent then
		local applyAct = -1 * amount;
		local added, reasons = AddActionApplyAct(actions, target, target, applyAct, 'Friendly');
		if ds then
			if added then
				ds:UpdateBattleEvent(GetObjKey(target), 'AddWait', { Time = applyAct });
			end
			ReasonToUpdateBattleEventMulti(target, ds, reasons);
			ds:UpdateBattleEvent(GetObjKey(target), 'MasteryInvokedCustomEvent', { Mastery = mastery_AccelerationEnergy.name, EventType = 'Ending', MissionChat = true, WorldEventType = ''  });
		else
			if added then
				AddBattleEvent(target, 'AddWait', { Time = applyAct });
			end
			ReasonToAddBattleEventMulti(target, reasons, 'Ending');
			AddMasteryInvokedEvent(target, mastery_AccelerationEnergy.name, 'Ending');
		end
		-- 보조전력
		local mastery_AuxiliaryPower = GetMasteryMastered(masteryTable, 'AuxiliaryPower');
		if mastery_AuxiliaryPower then
			InsertBuffActions(actions, target, target, mastery_AuxiliaryPower.Buff.name, amount, true, nil, ds == nil);
			if ds then
				MasteryActivatedHelper(ds, mastery_AuxiliaryPower, target, 'SPIncreased');
			else
				AddMasteryInvokedEvent(target, mastery_AuxiliaryPower.name, 'Ending');
			end
		end
		-- 강화된 신경망
		local mastery_EnhancedNeuralNetwork = GetMasteryMastered(masteryTable, 'EnhancedNeuralNetwork');
		if mastery_EnhancedNeuralNetwork then
			InsertBuffActions(actions, target, target, mastery_EnhancedNeuralNetwork.Buff.name, amount, true, nil, ds == nil);
			if ds then
				MasteryActivatedHelper(ds, mastery_EnhancedNeuralNetwork, target, 'SPIncreased');
			else
				AddMasteryInvokedEvent(target, mastery_EnhancedNeuralNetwork.name, 'Ending');
			end
		end
	end
end
function AddSPPropertyActionsObject(actions, target, amount, isStatusUpdate, ds, sequential)
	AddSPPropertyActions(actions, target, target.ESP.name, amount, isStatusUpdate, ds, sequential);
end
function AddOverchargeActionsObject(actions, target, ds)
	if target.Overcharge then
		table.insert(actions, Result_PropertyUpdated('Overcharge', target.OverchargeDuration, target, false, true));
	else
		AddSPPropertyActionsObject(actions, target, target.MaxSP - target.SP, true, ds, true);
	end
end
----------------------------------------------------------------
-- 유저 멤버 체크
----------------------------------------------------------------
function IsUserMember(unit)
	if unit.IsUserMember then
		return true;
	end
	if GetInstantProperty(unit, 'CUSTOM_USER_MEMBER') then
		return true;
	end
	return false;
end