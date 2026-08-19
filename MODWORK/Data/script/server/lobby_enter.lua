function MasterLobbyEnterDialogScript(lobbyType, ldm, company)
	-- 공용 로직
	LobbyEnter(ldm, company, lobbyType);
	-- 개별 로직.
	local _, terminated = LobbyEnterEvent(ldm, company, lobbyType, true);
	if terminated then
		return;
	end
	local func = _G['LobbyEnter_' ..lobbyType];
	if func then
		func(ldm, company);
	end	
	if lobbyType == company.LastLocation.LobbyType then
		LobbyEnterPost(ldm, company, lobbyType);
	end
end
function LobbyEnter(ldm, company, lobbyType)
	-- 리포트 갱신 로직.
	local dc = ldm:GetDatabaseCommiter();

	-- 로스터 장착 아이템 Amount 이슈 방어
	CheckRosterEquipItemAmount(company);
	
	-- 업적 갱신 (나중에 추가된 업적이나, 갱신 타이밍을 놓친 업적들을 추가 처리함)
	CheckAchievements(ldm, company, dc);
	
	-- ErrorCorrection
	CheckDataErrors(ldm, company, dc);
	
	-- 클래스 레벨에 따른 업데이트
	CheckRosterJobLevel(ldm, company, dc);
	
	-- 세트 마스터리 언락처리
	if lobbyType ~= 'LandOfStart' then
		CheckMasterySetIndex(ldm, company, dc);
	end
	
	-- 특성 연구 언락처리
	CheckTechniqueUnlock(ldm, company, dc);
		
	-- 제작 레시피 언락처리
	CheckRecipeUnlock(ldm, company, dc);
	
	-- 야수 어빌리티 활성화
	CheckBeastActiveAbility(ldm, company, dc);
	
	-- 기계 공용 마스터리 장착 해제
	CheckMachineInvalidMastery(ldm, company, dc);
	
	-- 무기 코스튬
	CheckTransmogOpened(ldm, company, dc);
	
	-- 합동 훈련 AI팀 알림
	if lobbyType ~= 'LandOfStart' then
		CheckJointTrainingBotTeamNotified(ldm, company, dc);
	end
	
	-- 아시아 서버 한정 보상 지급
--	CheckAsiaServerErrorReward(ldm, company, dc);

	-- 우호도 최초 보정
	CheckPCFriendshipFix(ldm, company, dc);

	-- DLC 진행에 따른 최대 레벨 언락
	CheckCharLvLimitByDLC(ldm, company, dc);
	
	local isResetActivityReport = company.ResetActivityReport;
	if isResetActivityReport then
		
		ResetActivityReport(dc, company);		
		
		-- 회사 리셋 리포트 프로퍼티 값 변경.
		dc:UpdateCompanyProperty(company, 'ResetActivityReport', false);
		dc:Commit('InitializeActivityReport');
	end
	
	-- 새로운 지역 이동 갱신 여부
	local curLocation = company.Waypoint[lobbyType];
	if curLocation and curLocation.name ~= nil then
		if curLocation.IsNew then
			local dc = ldm:GetDatabaseCommiter();
			dc:UpdateCompanyProperty(company, string.format('Waypoint/%s/IsNew',lobbyType), false);
			dc:Commit('IsNewUpdateLocation');
		end
	end
	
	-- 회사 운영에 관련된 공용 로직을 로비 타입에 따라 비활성화함	
	local lobbyCls = GetClassList('LobbyWorldDefinition')[lobbyType];
	if not lobbyCls.EnableCommonLobbyEnter then
		return;
	end	
	
	-- 영입 로직.
	for key, roster in pairs(company.Scout) do
		if roster.NeedScout then
			ProgressDialog(ldm, nil, company, 'Initial_SetRosterInfo_NeedScout', {roster_name=roster.name});
		end
	end
	
	local allRosters = GetAllRoster(company);
	if #allRosters > 1 then	-- 혹시나 싶어서..
		-- 로스터 레벨 켈리브레이션
		local companyLevelSum = 0;
		for _, r in ipairs(allRosters) do
			companyLevelSum = companyLevelSum + r.Lv;
		end
		for _, r in ipairs(allRosters) do
			if r.NeedLevelAdjustment then
				local companyMeanLv = math.floor((companyLevelSum - r.Lv) / (#allRosters - 1));
				dc:UpdatePCProperty(r, 'NeedLevelAdjustment', false);

				local levelDv = companyMeanLv - r.Lv;
				if levelDv >= 2 then
					local addLv = math.floor(levelDv / 2);
					dc:UpdatePCProperty(r, 'Lv', r.Lv + addLv);
					ldm:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('RosterLevelAdjusted'), {RosterName = ClassDataText('Pc', r.name, 'Info', 'Title'), Level = addLv}));
					ldm:AddChat('Notice', FormatMessageText(GuideMessageText('RosterLevelAdjustedChat'), {RosterName = ClassDataText('Pc', r.name, 'Info', 'Title'), Level = addLv}), {});
				end
			end
		end
	end
	
	-- 회사 이름이 유효한지 테스트
	if company.CompanyName ~= company.InvalidCompanyName then
		local isValid, reason, reasonSub = IsValidCompanyName(company.CompanyName);
		if not isValid and reason == 'SystemToken' then
			dc:GiveSystemMailOneKey(company, 'CompanyName_SystemToken', false, { CompanyName = company.CompanyName, InvalidToken = reasonSub });
			dc:UpdateCompanyProperty(company, 'InvalidCompanyName', company.CompanyName);
			dc:UpdateCompanyProperty(company, 'LastNameChangeTime', 0);
			dc:Commit('CheckIsValidCompanyName');
		end
	end
	
	-- 활동 보고서
	if company.ActivityReportCounter > 0 and company.ActivityReportDuration > 0 and company.ActivityReportCounter >= company.ActivityReportDuration then
		ProgressDialog(ldm, nil, company, 'ActivityReport_Main', {});
	end	
	
	-- 메일 쓰기 활성화
	if StringToBool(company.LobbyMenu.ZoneMove.Opened, false) and not StringToBool(company.LobbyMenu.MailBox.Write, false) then
		ProgressDialog(ldm, nil, company, 'Pierto_Tutorial_ZoneMove_MailWrite');
	end
	
	-- 로비 가이드 트리거
	ProgressLobbyGuideTrigger(ldm, company, { EventType = 'LobbyEnter', EventArgs = { LobbyType = lobbyType }});	

	-- DLC 코스튬 지급 (캐릭터 영입 시점에 DLC가 이미 있으면 바로 지급, 영입 이후에 구입/설치했으면 여기서 후처리로 지급)
	CheckDLCCostume(ldm, company, dc);
end
function LobbyEnterPost(ldm, company, lobbyType)
	-- 회사 운영에 관련된 공용 로직을 로비 타입에 따라 비활성화함
	local lobbyCls = GetClassList('LobbyWorldDefinition')[lobbyType];
	if not lobbyCls.EnableCommonLobbyEnter then
		return;
	end

	if company.OfficeRentVill > 0 and company.OfficeRentDuration > 0 and company.OfficeRentCounter >= company.OfficeRentDuration + company.OfficeRentCountDelayCont then
		ProgressDialog(ldm, nil, company, 'OfficeRent_Main', {});
	end	
	local rosterList = GetAllRoster(company);
	for _, roster in ipairs(rosterList) do
		if roster.Salary > 0 and roster.SalaryDuration > 0 and roster.SalaryCounter >= roster.SalaryDuration + roster.SalaryCountDelayCont then
			ProgressDialog(ldm, nil, company, 'Salary_Main', {roster_name=roster.name});
		end
	end
	for _, roster in ipairs(rosterList) do
		if roster.Salary > 0 and roster.SalaryDuration > 0 and (not roster.SalaryNoticed) and roster.SalaryCounter + 1 == roster.SalaryDuration then
			ProgressDialog(ldm, nil, company, 'Salary_Notice', {roster_name=roster.name});
		end
	end
	
	-- PC 우호도
	UpdateMissionPCFriendship(ldm, company);
end
function LobbyEnterEvent(ldm, company, lobbyType, isRoot)
	local lobbyEnterCls = GetClassList('LobbyEnter')[lobbyType];
	if not lobbyEnterCls then
		return false;
	end
	-- 모든 로비 공통으로 시작하는 이벤트.
	local prevEvent = lobbyEnterCls.PrevEvent;
	if prevEvent and prevEvent ~= lobbyType and prevEvent ~= 'None' then
		local prevEventCls = GetClassList('LobbyEnter')[prevEvent];
		if prevEventCls then
			local processed, terminated = LobbyEnterEvent(ldm, company, prevEvent, false);
			if processed then
				return true, terminated;
			end
		end
	end
	-- 개별 로비에서 조건 만족 시 시작하는 이벤트
	for _, entry in ipairs(lobbyEnterCls.Dialogs) do
		local isEnable = false;
		if entry.CheckType == 'Stage' then
			if entry.Stage then
				isEnable = company.MissionCleared[entry.Stage];
			end
		elseif entry.CheckType == 'Property' then
			local curValue = SafeIndex(company, unpack(string.split(entry.Key, '/')));
			if curValue ~= nil then
				if type(entry.Value) == 'number' then
					isEnable = curValue == entry.Value;
				else
					isEnable = tostring(curValue) == tostring(entry.Value);
				end
			end
		elseif entry.CheckType == 'Property2' then
			local curValue = SafeIndex(company, unpack(string.split(entry.Key, '/')));
			if curValue ~= nil then
				if type(entry.Value) == 'number' then
					isEnable = curValue == entry.Value;
				else
					isEnable = tostring(curValue) == tostring(entry.Value);
				end
			end
			local curValue2 = SafeIndex(company, unpack(string.split(entry.Key2, '/')));
			if curValue2 ~= nil then
				if type(entry.Value2) == 'number' then
					isEnable = isEnable and (curValue2 == entry.Value2);
				else
					isEnable = isEnable and (tostring(curValue2) == tostring(entry.Value2));
				end
			end
		elseif entry.CheckType == 'Custom' then
			local checkFunc =  _G[entry.Script];
			if checkFunc then
				local succ, ret = pcall(checkFunc, company, entry);
				if succ then
					isEnable = ret;
				else
					LogAndPrint('LobbyEnterEvent checkFunc Failed! - dialog:', entry.Dialog, ', error:', ret);
				end
			end
		end	
		if isEnable then
			-- 이벤트 있을 때의 자동 FadeIn 처리 (페이드 아웃 상태에서 이벤트 연출이 필요한 경우에는 false로 설정하고, 이벤트에서 직접 FadeOut 처리를 해야함)
			if StringToBool(entry.AutoFadeIn, false) then
				ldm:SceneFadeOut('', true);
				ldm:SceneFadeIn('', false);
			end
			local env = ProgressDialog(ldm, nil, company, entry.Dialog, {});
			return true, env._terminated;
		end
	end
	-- 아무런 이벤트가 없을 때의 자동 FadeIn 처리 (이게 없으면, 클라이언트에서 발생하는 이벤트나 시스템 메시지들이 로딩 화면이 사라지는 도중에 나올 수 있음)
	if lobbyEnterCls.AutoFadeIn and isRoot then
		ldm:SceneFadeOut('', true);
		ldm:SceneFadeIn('', false);
	end
	return false;
end
function LobbyEnter_Office(ldm, company)

end
function LobbyEnter_Office_Albus(ldm, company)

end
function LobbyEnter_Office_Night(ldm, company)

end
function LobbyEnter_ShooterStreet(ldm, company)

end
function LobbyEnter_LandOfStart(ldm, company)

end


--- return nil => 로비 진입 계속
--- return string, table of string => 로비 진입 중단 및 리턴 타입의 미션과 라인업으로 직행
function MasterLobbyPreenterMission_Script(company, lobbyType, dc)
	local func = _G['LobbyPreenterMission_' ..lobbyType];
	if func then
		return func(company, dc);
	end
	return nil, nil;
end

function LobbyPreenterMission_Office(company, dc)
	local openingStage = company.Progress.Tutorial.Opening;	
	if openingStage == 'CrowBill' then
		return 'Tutorial_CrowBill', {};
	elseif openingStage == 'SkipTutorial' then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'FireflyPark');
		dc:Commit('SkipTutorial');
		return 'Tutorial_FireflyPark', {};
	elseif openingStage == 'FireflyPark' then
		return 'Tutorial_FireflyPark', {};
	end
end
function LobbyPreenterMission_LandOfStart(company, dc)
	local openingStage = company.Progress.Tutorial.Opening;
	if openingStage == 'CrowBill' then
		return 'Tutorial_CrowBill', {};
	elseif openingStage == 'FireflyPark' then
		return 'Tutorial_FireflyPark', {};
	elseif openingStage == 'Silverlining' then
		return 'Tutorial_Silverlining', {};
	elseif openingStage == 'PugoStreet' then
		return 'Tutorial_PugoStreet', {};
	elseif openingStage == 'Road_113' then
		return 'Tutorial_Road_113', {};
	end
	return nil;
end

function MasterLobbyPreenterLobby_Script(company, lobbyType, dc)
	local func = _G['LobbyPreenterLobby_' ..lobbyType];
	if func then
		return func(company, dc);
	end
	return nil, nil;
end

function LobbyPreenterLobby_Office(company, dc)
	-- 1. 창고 강화, 분해 오픈.
	if (company.Progress.Tutorial.Office == 41 or company.Progress.Tutorial.Office == 42
		or company.Progress.Tutorial.Office == 43)
		and company.Office == 'Office_Silverlining_Workshop'
		and company.MissionCleared.Tutorial_PurpleBackStreet
	then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', false);
		if company.Progress.Tutorial.Office == 41 then
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office', 42);
		end
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 1);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('ItemUpgradeChangeLocation') then
			return 'Office_Night';
		end
	end
	-- 2. 사무실, 사수거리 공용 이벤트 처리
	local ret = LobbyPreenterLobby_CommonEvent(company, dc, 'Office');
	if ret then
		return ret;
	end
	return nil;
end
function LobbyPreenterLobby_ShooterStreet(company, dc)
	-- 1. 사무실, 사수거리 공용 이벤트 처리
	local ret = LobbyPreenterLobby_CommonEvent(company, dc, 'ShooterStreet');
	if ret then
		return ret;
	end
	return nil;
end
function LobbyPreenterLobby_Office_Night(company, dc)
	-- 까마귀 폐허 미션 - 승리 / 패배
	if company.Progress.Character.Heissing == 10 then
		ReserveChangeLocationCore(dc, company, 'Office');
		if dc:Commit('HeissingReturnConversation') then
			return 'Office';
		end
	end	
	return nil;
end

function LobbyPreenterLobby_CommonEvent(company, dc, location)
	-- 2. 시온 이벤트.
	if company.Progress.Character.Sion == 0
		and company.MissionCleared.Tutorial_PurpleStreet
	then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Sion', 1);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 2);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('SionAlbusConversation') then
			return 'Office_Night';
		end
	end
	-- 3. 재료 도감 열기.
	-- 제작대 오픈 이후.
	if not StringToBool(company.OfficeMenu.ItemBook.Opened, false)
		and StringToBool(company.OfficeMenu.TroublemakerList.Opened, false)
		and StringToBool(company.OfficeMenu.TroubleBook.Opened, false)
	then
		local eventEnabled = false;
		if company.Progress.Tutorial.ItemBook == 0 then
			-- 작업대 오픈 이후 제작을 1번이라도 했으면, 재료 도감 오픈 이벤트가 진행이 가능하게 처리
			-- 강화/분해/추출은 따로 경험치 정보가 없으므로, 패치 이전에 한 적이 있어도 어쩔 수가 없다.
			if StringToBool(company.WorkshopMenu.Upgrade.Opened) then
				for _, recipe in pairs(company.Recipe) do
					if recipe.Opened and recipe.Exp > 0 then
						eventEnabled = true;
						break;
					end
				end
			end
		elseif company.Progress.Tutorial.ItemBook <= 3 then
			eventEnabled = true;
		end
		if eventEnabled then
			dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/ItemBook', 2);
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/ItemBookEvent', true);
			ReserveChangeLocationCore(dc, company, 'Office_Night');
			if dc:Commit('ItemBookConversation') then
				return 'Office_Night';
			end
		end
	end
	
	-- 4. 헤이싱, 앤 이벤트
	-- 잿빛 항구 H 물류 창고 완료 후.
	if company.Progress.Character.Anne == 5
		and company.Progress.Character.Heissing	== 7
		and company.MissionCleared.Tutorial_GrayPortWareHouse
	then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 3);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('AnneHeissingConversation') then
			return 'Office_Night';
		end
	end
	-- 5. 헤이싱, 알버스 이벤트
	-- 먼지바람 톨게이트 완료 후.
	if company.Progress.Character.Ray == 4 and company.MissionCleared.Tutorial_DustWind then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 4);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('AlbusHeissingConversation') then
			return 'Office_Night';
		end
	end
	-- 6. 알버스. 지젤. 앤 이벤트.
	-- 은빛구름시장거리 완료 후
	if company.Progress.Character.Albus == 10 and company.MissionCleared.Tutorial_DustWindRestArea then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', true);
		dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 5);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('AlbusGiselleAnneConversation') then
			return 'Office_Night';
		end
	end	
	-- 7. 헤이싱, 레이 이벤트
	-- 자홍거리 상점가 이후
	if company.Progress.Character.Heissing == 8 and company.MissionCleared.Tutorial_PurpleStreetAfter then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 6);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('RayHeissingConversation') then
			return 'Office_Night';
		end
	end
	-- 8. 알버스, 돈 이벤트
	-- 푸고샵 애프터 이후
	if company.Progress.Character.Albus == 17 and company.MissionCleared.Tutorial_PugoStreetAfter then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 7);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('AlbusDonConversation') then
			return 'Office_Night';
		end
	end
	
	-- 9. 레톤 영입 미션
	-- 레톤 영입 미션
	if company.Progress.Character.Leton == 2 and company.MissionCleared.Tutorial_GroundWaterSlum then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 8);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('LetonVisitConversation') then
			return 'Office_Night';
		end
	end	
	
	-- 10. 까마귀 폐허 미션	-- 헤이싱 이탈
	if company.Progress.Character.Heissing == 9 and company.MissionCleared.Tutorial_CrowRuinsAfter then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 9);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('HeissingAbsentConversation') then
			return 'Office_Night';
		end
	end

	-- 11. 하늘바람 포장마차 완료
	if company.Progress.Character.Albus == 20 and company.MissionCleared.Tutorial_SkyBlueAfter then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 10);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('KylieAbsentConversation') then
			return 'Office_Night';
		end
	end

	-- 12. 미워도 다시 한번 완료.
	if company.Progress.Character.Albus == 23 and company.MissionCleared.Tutorial_PurpleStreet_Kylie then
		if location ~= 'Office' then
			ReserveChangeLocationCore(dc, company, 'Office');
		end
		if dc:Commit('RayGloomyConversation') then
			if location ~= 'Office' then
				return 'Office';
			end
		end
	end
	
	-- 13. 서로를 위해 완료.
	if company.Progress.Character.Albus == 25 and company.MissionCleared.Tutorial_TrainingRoomAfter then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 11);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('DonReminiscenceConversation') then
			return 'Office_Night';
		end
	end
	
	-- 14. 알리사, 비앙카 영입 실패 복구
	if company.Progress.Tutorial.Opening == 'ScoutBiancaAlisa_End' and location ~= 'LandOfStart' then
		-- 비앙카 영입
		if GetRoster(company, 'Bianca') == nil then
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'ScoutBiancaFailover');
			ReserveChangeLocationCore(dc, company, 'LandOfStart');
			if dc:Commit('ScoutBiancaFailover') then
				return 'LandOfStart';
			end
		end
		-- 알리사 영입
		if GetRoster(company, 'Alisa') == nil then
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'ScoutAlisaFailover');
			ReserveChangeLocationCore(dc, company, 'LandOfStart');
			if dc:Commit('ScoutAlisaFailover') then
				return 'LandOfStart';
			end
		end
	end

	-- 15. 트러블북으로 미진행 미션 시작에 따른 스토리 진행 꼬임 복구
	if company.MissionCleared.Tutorial_GrayCemeteryParkAfter and company.Progress.Character.Albus < 6 then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Giselle', 2);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Albus', 6);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'ScoutGiselle');
		local roster = GetRoster(company, 'Albus');
		if roster then
			dc:UpdatePCProperty(roster, 'Personalities/Albus_EmptyPlaceOfMe/Opened', true);
		end
		ReserveChangeLocationCore(dc, company, 'LandOfStart');
		if dc:Commit('GrayCemeteryParkAfteFailover') then
			return 'LandOfStart';
		end
	end
	
	-- 16. Tutorial_CrowRuinsAfter_Serpent 이후 임시 로비 변경
	if company.Progress.Character.Albus == 62 and location ~= 'Office' then
		ReserveChangeLocationCore(dc, company, 'Office');
		if dc:Commit('PascalAttackPolice') then
			return 'Office';
		end
	end

	return nil;
end
function GetLobbyEnterLoadingAndBGM(company, lobbyType)
	-- 밤 오피스.
	if lobbyType == 'Office_Night' then		
		if company.Progress.Character.Anne == 5	and company.Progress.Character.Heissing	== 7 and company.MissionCleared.Tutorial_GrayPortWareHouse 	then
			return 'Lobby_Office_HeissingAndAnne', 'Arrival';
		end
		if company.Progress.Character.Ray == 4 and company.MissionCleared.Tutorial_DustWind	then
			return 'Lobby_Office_HeissingAndRay', 'AloneTime';
		end
	end
	if lobbyType == 'Office' then
		if company.Progress.Character.Heissing == 10 then 
			return 'Lobby_Office_Heissing', 'FairyTale';
		end
	end
	if lobbyType == 'Office' then
		if company.MissionCleared.Tutorial_BlackMarket and company.Progress.Character.Albus == 30 then 
			return 'Lobby_Office_WhiteLionAndBlackWitch', 'ChuncheonAndFall';
		end
	end
	if lobbyType == 'Office' then
		if company.Progress.Character.Albus == 60 then 
			return 'Lobby_Office_Misty', 'MemoriesHazedInRain';
		end
	end
end
local g_hiddenTechMap = nil;
function CheckSituationTechniqueHidden(company)
	if not g_hiddenTechMap then
		g_hiddenTechMap = {};
		local techList = GetClassList('Technique');
		for _, tech in pairs(techList) do
			for _, unlockTech in ipairs(tech.UnLockTechnique) do
				g_hiddenTechMap[unlockTech] = true;
			end
		end
	end
	
	for key, _ in pairs(g_hiddenTechMap) do
		if company.Technique[key].Opened then
			return true;
		end		
	end
	return false;
end
function CheckStorySkyWindParkAllSelect(company)
	if company.Progress.Character.GiselleTraining == 0		-- 알버스
		or not company.Technique.Hysterie.Opened 			-- 시온
		or not company.Technique.HeroResponsibility.Opened	-- 아이린
		or not company.Technique.Waiting.Opened				-- 앤
		or company.Progress.Character.Kylie == 2			-- 헤이싱
		or not company.Technique.ColdRefusal.Opened			-- 레이
	then
		return false;
	end
	return true;
end
function CheckSituationFirstMachine(company)
	return company.MachineIndex > 0;
end
function MakeMissionClearTester(missionType)
	return function(company) return company.MissionCleared[missionType] end;
end
local g_checkAchievementFuncs = {
	StoryTroubleshooter = function(company) return GetRoster(company, 'Albus') ~= nil; end,
	StoryOfficeAlbus = function(company) return company.Progress.Tutorial.Roster >= 12; end,
	StoryOfficeSilverlining = function(company) return company.Office ~= 'Office_Albus'; end,
	StoryRamjiPlaza = function(company) return company.Progress.Tutorial.Office >= 20; end,
	StoryPugoStreet = function(company) return GetRoster(company, 'Sion') ~= nil; end,
	StoryConstructionA = function(company) return company.Progress.Character.Irene >= 2; end,
	StoryRoad113 = function(company) return company.Progress.Character.Pierto >= 1; end,
	StoryCrowBillAfter = function(company) return company.Progress.Character.Irene >= 3; end,
	StoryPugoShop = function(company) return company.Progress.Character.Heissing >= 2; end,
	StoryPurpleBackStreet = function(company) return company.Progress.Character.Issac >= 2; end,
	StoryPugoBackStreet = function(company) return company.Progress.Character.Sharky >= 2; end,
	StoryHansando = function(company) return company.Progress.Character.Kylie >= 1; end,
	StoryGrayCemeteryPark = function(company) return company.Progress.Character.Anne >= 4; end,
	StoryLokoCabin = function(company) return company.Progress.Character.Issac >= 6; end,
	StoryOrsay = function(company) return company.Progress.Character.Danny >= 1; end,
	StoryLasa = function(company) return company.Progress.Character.Ryo >= 1; end,
	StorySkyBlue = function(company) return company.Progress.Character.Issac >= 7; end,
	StoryPurpleStreet = function(company) return company.Progress.Character.Ryo >= 2 end,
	StoryPugoShopAfter = function(company) return company.Progress.Character.Heissing >= 3 end,
	StoryRoad112 = function(company) return company.MissionCleared.Tutorial_Road_112 end,
	StoryMetroStreet = function(company) return company.MissionCleared.Tutorial_MetroStreet end,
	StoryStarStreet = function(company) return company.MissionCleared.Tutorial_StarStreet end,
	StoryCrescentBridge = function(company) return company.MissionCleared.Tutorial_CrescentBridge end,
	StoryGrayPortWareHouse = function(company) return company.MissionCleared.Tutorial_GrayPortWareHouse end,
	StorySkyWindPark = function(company) return company.MissionCleared.Tutorial_SkyWindPark end,
	StoryTrainingRoom = function(company) return company.MissionCleared.Tutorial_TrainingRoom end,
	StoryPugoBackStreetAfter = function(company) return company.MissionCleared.Tutorial_PugoBackStreetAfter end,
	StoryRoad111 = function(company) return company.MissionCleared.Tutorial_Road_111 end,
	StoryDustWindRestArea = MakeMissionClearTester('Tutorial_DustWindRestArea'),
	SituationTechniqueHidden = CheckSituationTechniqueHidden,
	StoryGrayCemeteryParkAfter = MakeMissionClearTester('Tutorial_GrayCemeteryParkAfter'),
	ChallengeSkyWindParkAllSelect = CheckStorySkyWindParkAllSelect,
	StoryMarketStreet = MakeMissionClearTester('Tutorial_MarketStreet'),
	StoryRoad110 = function(company) return company.MissionCleared.Tutorial_Road_110 end,
	SituationFirstMachine = CheckSituationFirstMachine,
	StoryPurpleStreetAfter = MakeMissionClearTester('Tutorial_PurpleStreetAfter'),
	StoryCrowRuins = MakeMissionClearTester('Tutorial_CrowRuins'),
	StoryCrowRuinsAfter = MakeMissionClearTester('Tutorial_CrowRuinsAfter'),
	StoryPugoStreetAfter = MakeMissionClearTester('Tutorial_PugoStreetAfter'),
	StoryWasteBuilding = MakeMissionClearTester('Tutorial_WasteBuilding'),
	StoryGroundWaterSlum = MakeMissionClearTester('Tutorial_GroundWaterSlum'),
	RosterIrene = function(company) return GetRoster(company, 'Irene') ~= nil; end,
	RosterAnne = function(company) return GetRoster(company, 'Anne') ~= nil; end,
	RosterHeissing = function(company) return GetRoster(company, 'Heissing') ~= nil; end,
	RosterRay = function(company) return GetRoster(company, 'Ray') ~= nil; end,
	RosterGiselle = function(company) return GetRoster(company, 'Giselle') ~= nil; end,
	RosterKylie = function(company) return GetRoster(company, 'Kylie') ~= nil; end,
	RosterLeton = function(company) return GetRoster(company, 'Leton') ~= nil; end,
	RosterAlisa = function(company) return GetRoster(company, 'Alisa') ~= nil; end,
	RosterBianca = function(company) return GetRoster(company, 'Bianca') ~= nil; end,
	ChallengeDrakyNestFindWay = function(company) return company.Progress.Mission.DrakyNest end,
	StoryCrowRuinsAfterAlley = MakeMissionClearTester('Tutorial_CrowRuinsAfter_Alley'),
	StorySkyBlueAfter = MakeMissionClearTester('Tutorial_SkyBlueAfter'),
	StoryPurpleStreetKylie = MakeMissionClearTester('Tutorial_PurpleStreet_Kylie'),
	StoryTrainingRoomAfter = MakeMissionClearTester('Tutorial_TrainingRoomAfter'),
	StorySilverliningAfter = MakeMissionClearTester('Tutorial_SilverliningAfter'),
	StoryWhiteTigerBase = MakeMissionClearTester('Tutorial_WhiteTigerBase'),
	StoryBlackMarket = MakeMissionClearTester('Tutorial_BlackMarket'),
	SituationIreneKillLuna = function(company) return company.GuideTrigger.KillAchievement_IreneLuna.Pass end,
	SituationAlbusKillGiselle = function(company) return company.GuideTrigger.KillAchievement_AlbusGiselle.Pass end,
	SituationAnneKillAlbus = function(company) return company.GuideTrigger.KillAchievement_AnneAlbus.Pass end,
	SituationAnneKillIrene = function(company) return company.GuideTrigger.KillAchievement_AnneIrene.Pass end,	
	StoryMetroStreetAfter = MakeMissionClearTester('Tutorial_MetroStreetAfter'),
	StoryDLC1Ending = function(company) return company.Progress.Character.Albus >= 49 end,
	StoryHardwareStore = function(company) return company.MissionCleared.Tutorial_HardwareStore end,
};

function CheckRosterEquipItemAmount(company)
	local itemSlotList = GetItemSlotList();
	local rosterList = GetAllRoster(company, 'All');
	for _, pcInfo in ipairs(rosterList) do
		for index = 0, pcInfo.EquipmentSlot.Count - 1 do
			for _, itemSlot in ipairs(itemSlotList) do
				local curEquip = GetRosterEquipItem(pcInfo, itemSlot, index);
				if curEquip ~= nil then
					curEquip.Amount = 1;
				end
			end
		end
	end
end

---@param company company
---@param ldm DirectingScripterBase
---@param dc DatabaseCommiter
function CheckAchievements(ldm, company, dc)
	local needCommit = false;
	for name, checkFunc in pairs(g_checkAchievementFuncs) do
		if not company.CheckAchievements[name] and checkFunc(company) then
			ldm:UpdateAchievement(name, true);
			dc:UpdateCompanyProperty(company, string.format('CheckAchievements/%s', name), true);
			needCommit = true;
		end
	end
	-- 트러블메이커 업적 자동 체크 (AchievementCheckFunc가 없는 것만)
	for _, tmInfo in pairs(company.Troublemaker) do
		local achievement = SafeIndex(tmInfo.Achievement, 'name');
		if achievement and achievement ~= 'None' then
			if not company.CheckAchievements[achievement] and tmInfo.AchievementCheckFunc == 'None' and tmInfo.IsKill then
				ldm:UpdateAchievement(achievement, true);
				dc:UpdateCompanyProperty(company, string.format('CheckAchievements/%s', achievement), true);
				needCommit = true;
			end
		end
	end
	-- 가이드 트리거 업적 자동 체크
	for _, guideTrigger in pairs(company.GuideTrigger) do
		if guideTrigger.Pass then
			local achievement = GetWithoutError(guideTrigger, 'Achievement');
			if achievement and achievement ~= 'None' and not IsAchievementAchieved(company, achievement) then
				ldm:UpdateAchievement(achievement, true);
			end
		end
	end

	-- 가스가 부족해 Backward Compatibility
	---@type class_GuideTrigger
	local AbilityRay = company.GuideTrigger.AbilityRay;
	if not company.Progress.Achievement.AbilityRayCheck and IsAchievementAchieved(company, 'AbilityRay') then
		dc:UpdateCompanyProperty(company, 'Progress/Achievement/AbilityRayCheck', true);
		if company.MissionCleared.Tutorial_Silverlining and not AbilityRay.Pass then
			dc:UpdateCompanyProperty(company, 'GuideTrigger/AbilityRay/Pass', true);
			dc:AcquireMastery(company, AbilityRay.Mastery, 1);
			ldm:ShowFrontmessageWithText(GuideMessageText(AbilityRay.FrontmessageKey), 'Corn');
			needCommit = true;
		end
	end

	-- 내가 만든 것 Backward Compatibility
	if not company.Technique.FineTuning.Opened and CheckSituationFirstMachine(company) then
		dc:UpdateCompanyProperty(company, 'Progress/Achievement/FineTuningCheck', true);
		ldm:ShowFrontmessageWithText(GuideMessageText('FineTuningAchieved'), 'Corn');
		dc:AcquireMastery(company, 'FineTuning', 1);
		needCommit = true;
	end

	if company.Stats.TamingSuccessCount < company.BeastIndex then
		dc:UpdateCompanyProperty(company, 'Stats/TamingSuccessCount', company.BeastIndex);
		needCommit = true;
	end
	if needCommit then
		dc:Commit('CheckAchievements');
	end
end

function CheckDataErrors(ldm, company, dc)
	local needCommit = false;
	-- 괴수 사냥꾼
	if company.GuideTrigger.GiantKiller.Pass and not company.Technique.GiantKiller.Opened then
		dc:AcquireMastery(company, 'GiantKiller', 1);
		needCommit = true;
	end
	-- 작업대 오픈 프로퍼티 버그 수정
	if StringToBool(company.WorkshopMenu.Upgrade.Opened, false) and company.Progress.Tutorial.Office > 42 and company.Progress.Tutorial.Office < 45 then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office', 45);
		needCommit = true;
	end
	-- 레이 프로퍼티 버그 수정
	if company.MissionCleared.Tutorial_DustWind and company.Progress.Character.Ray < 4 then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Ray', 4);
		needCommit = true;
	end
	if GetRoster(company, 'Ray') and company.Progress.Character.Ray < 6 then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Ray', 6);
		needCommit = true;
	end
	-- 스토리 꼬임 버그
	if company.Progress.Character.Albus > 38 and not company.MissionCleared.Tutorial_ShadowStreet then
		dc:UpdateCompanyProperty(company, 'MissionCleared/Tutorial_ShadowStreet', 'true');
		needCommit = true;
	end
	if company.Progress.Character.Albus > 40 and not company.MissionCleared.Tutorial_RiverSideRoad then
		dc:UpdateCompanyProperty(company, 'MissionCleared/Tutorial_RiverSideRoad', 'true');
		needCommit = true;
	end
	-- 모듈 목록 안 열린 문제 수정
	if StringToBool(company.WorkshopMenu.Module.Opened, false) and not StringToBool(company.LobbyMenu.ModuleInventory.Opened, false) then
		dc:UpdateCompanyProperty(company, 'LobbyMenu/ModuleInventory/Opened', 'true');
		needCommit = true;
	end
	-- 레이 인연 버그 수정
	if company.Progress.Character.Albus >= 56 then
		local pc = GetRoster(company, 'Ray');
		IfHavePersonality(pc, 'Ray_UnvisibleWall', function(personality)
			dc:UpdatePCProperty(pc, 'Personalities/Ray_UnvisibleWall/Opened', false);
			needCommit = true;
		end);
	end
	-- 제트 스트림 어택 회수
	local rosterList = GetAllRoster(company, 'Pc');
	for _, roster in pairs(rosterList) do
		for slotIndex, bfMasteries in ipairs(roster.BestFriend) do
			local curBFMasteryList = {};
			for i = 1, 3 do
				local propName = string.format('Mastery%d', i);
				table.insert(curBFMasteryList, bfMasteries[propName]);
			end
			if table.find(curBFMasteryList, 'ZetStreamAtttack') then
				local newBFMasteryList = table.filter(curBFMasteryList, function(masteryName) return masteryName ~= 'ZetStreamAtttack' end);
				for i = 1, 3 do
					local curMastery = curBFMasteryList[i] or 'None';
					local newMastery = newBFMasteryList[i] or 'None';
					if curMastery ~= newMastery then
						dc:UpdatePCProperty(roster, string.format('BestFriend/%d/Mastery%d', slotIndex, i), newMastery);
						needCommit = true;
					end
				end
			end
		end
	end
	-- 온라인 -> 오프라인 동기화 시의 가혹한 난이도 언락 안 되는 버그 수정
	local account = GetAccount(company);
	if account and not account.DifficultyOpened.Merciless and company.OfficeMenu.TroubleBook.Opened then
		dc:UpdateAccountProperty(company, 'DifficultyOpened/Merciless', true);
		needCommit = true;
	end

	if needCommit then
		dc:Commit('CheckDataErrors');
	end
end

function EnterLobbySystemNoticeCheck(company)
	local worldProperty = GetWorldProperty();
	
	-- 치안도 피버
	local noticeType = 'SafetyFeverNow';
	local zoneState = worldProperty.ZoneState;
	if IsSingleplayMode() then
		noticeType = 'SafetyFeverNow_Single';
		zoneState = company.ZoneState;
	end
	
	local userZone = GetClassList('LobbyWorldDefinition')[GetUserLocation(company)].Zone.name;
	if zoneState[userZone].SafetyFever then
		local feverTime = zoneState[userZone].FeverTime;
		SendSystemNotice(company, noticeType, {ZoneName=userZone, OffsetTime = feverTime + GetSystemConstant('ZONE_SAFETY_FEVER_DURATION'), LeftMissionCount = company.ActivityReportDuration - company.ActivityReportCounter});
	end
end
function CheckRosterJobLevel(ldm, company, dc)
	local rosterList = GetAllRoster(company, 'All');
	
	-- 처음 접속 시, 현재 레벨에 따른 클래스 레벨 보정
	if company.NeedAdjustJobLv then
		for _, roster in ipairs(rosterList) do
			if roster.RosterType == 'Pc' then
				local rosterCls = GetClassList('Pc')[roster.name];
				local startLv = rosterCls.Lv;
				local startJob = rosterCls.Object.Job.name;
				local addLv = roster.Lv - startLv;
				if addLv > 0 then			
					local jobKey = string.format('EnableJobs/%s/Lv', startJob);
					local expKey = string.format('EnableJobs/%s/Exp', startJob);
					
					local jobLv = 1;
					local jobExp = 0;
					if addLv >= 11 then
						jobLv = 10;
					elseif addLv >= 7 then
						jobLv = 8;
					elseif addLv >= 4 then
						jobLv = 6;
					end
					
					local prevJobLv = SafeIndex(roster, unpack(string.split(jobKey, '/')));
					if jobLv > prevJobLv then
						dc:UpdatePCProperty(roster, jobKey, jobLv);
						dc:UpdatePCProperty(roster, expKey, jobExp);
					end
				end
			end
		end
		dc:UpdateCompanyProperty(company, 'NeedAdjustJobLv', false);
		dc:Commit('NeedAdjustJobLv');
	end	

	-- 클래스 레벨에 따른 보상 특성 중에 언락이 안 된 것이 남아있으면 
	-- 직업 개방에 따른 추가 특성판
	local updateTechnique = false;
	for _, roster in ipairs(rosterList) do
		local rewardMasteries = {};
		if roster.RosterType == 'Pc' then
			local extraBoard = 0;
			local enableJobs = roster.EnableJobs;
			for jobName, job in pairs(enableJobs) do
				local rosterCls = GetClassList('Pc')[roster.name];
				local startJob = rosterCls.Object.Job.name;
				local isOpened = false;
				if jobName == startJob then
					isOpened = true;
				elseif IsSatisfiedChangeClass(roster, jobName) and (job.Lv > 1 or job.LastLv > 0) then
					isOpened = true;
				end
				if isOpened then
					table.append(rewardMasteries, GetRewardMasteriesByJobLevel(company, roster, jobName, 1, job.Lv));
				end
				if isOpened and StringToBool(job.ExtraMasteryBoard) then
					extraBoard = extraBoard + 1;
					dc:UpdatePCProperty(roster, string.format('EnableJobs/%s/ExtraMasteryBoard', jobName), false);
				end
			end
			if extraBoard > 0 then
				dc:AddPCProperty(roster, 'MasteryBoard/ExtraCount', extraBoard);
			end
		elseif roster.RosterType == 'Beast' then
			rewardMasteries = GetRewardMasteriesByJobLevel_Beast(company, roster, roster.LastJobLv, roster.JobLv);
			if #rewardMasteries > 0 then
				dc:UpdatePCProperty(roster, 'LastJobLv', roster.JobLv);
			end
		elseif roster.RosterType == 'Machine' then
			rewardMasteries = GetRewardMasteriesByJobLevel_Machine(company, roster, roster.LastJobLv, roster.JobLv);
			if #rewardMasteries > 0 then
				dc:UpdatePCProperty(roster, 'LastJobLv', roster.JobLv);
			end
		end
		updateTechnique = updateTechnique or #rewardMasteries > 0;
		for _, mastery in ipairs(rewardMasteries) do
			local techName = mastery.name;
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', techName), true);
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', techName), true);
		end
	end
	if updateTechnique then
		dc:Commit('UpdateTechniqueByJobLevel');
	end
end
function CheckMasterySetIndex(ldm, company, dc)
	local rosterList = GetAllRoster(company, 'All');
	for _, roster in ipairs(rosterList) do
		local allMasteryTable = {};
		for i = 1, roster.MasteryBoard.Count do
			local boardIndex = i - 1;
			local masteryTable = GetMastery(roster, boardIndex);
			for k, mastery in pairs(masteryTable) do
				-- 聚合该角色全部天赋板的已装备天赋，供下方按 XZJF_SetMasteryMinCount 阈值解锁判定使用
				allMasteryTable[k] = mastery;
				if mastery.Lv > 0 and mastery.Category.name == 'Set' then
					local open = company.MasterySetIndex[mastery.name];
					if open == false then
						dc:UpdateCompanyProperty(company, 'MasterySetIndex/'..mastery.name, true);
						-- 중복 방지를 위한 수동 업데이트
						company.MasterySetIndex[mastery.name] = true;
						local formatTable = {
							MasteryName = ClassDataText('Mastery', k, 'Title'),
						};
						local text = FormatMessageText(GuideMessageText('MasterySetAvailableByUpdate'), formatTable);
						ldm:ShowFrontmessageWithText(text);
						ldm:AddChat('Notice', RemoveTagText(text));
					end
				end
			end
		end
		-- [MOD] 附加天赋效果信息解锁条件放宽（兜底）：
		-- 原版仅当角色装备了完整的 Set 天赋（Category=Set）时才解锁图鉴信息；
		-- 现改为已装备子天赋达到 XZJF_SetMasteryMinCount 个即解锁（与生效、
		-- 界面显示阈值一致，见 shared_mastery.lua 顶部常量说明）。
		for key, cls in pairs(GetClassList('MasterySet')) do
			if not company.MasterySetIndex[key] then
				local needCount = 0;
				local hasCount = 0;
				for _, propName in ipairs({'Mastery1', 'Mastery2', 'Mastery3', 'Mastery4'}) do
					local propValue = cls[propName];
					if propValue ~= 'None' then
						needCount = needCount + 1;
						local m = allMasteryTable[propValue];
						if m and m.Lv > 0 then
							hasCount = hasCount + 1;
						end
					end
				end
				if needCount > 0 and hasCount >= XZJF_SetMasteryMinCount then
					dc:UpdateCompanyProperty(company, 'MasterySetIndex/'..key, true);
					company.MasterySetIndex[key] = true;
					local formatTable = {
						MasteryName = ClassDataText('Mastery', key, 'Title'),
					};
					local text = FormatMessageText(GuideMessageText('MasterySetAvailableByUpdate'), formatTable);
					ldm:ShowFrontmessageWithText(text);
					ldm:AddChat('Notice', RemoveTagText(text));
				end
			end
		end
	end
		
	-- 트러블메이커 특성 세트 언락
	for key, cls in pairs(GetClassList('MasterySet')) do
		(function()
			if not company.MasterySetIndex[key] then
				local troublemakers = cls.HavingTroublemakers;
				for troublemaker, _ in pairs(troublemakers) do
					if GetTroublemakerInfoGrade(company.Troublemaker[troublemaker]) >= 4 then
						dc:UpdateCompanyProperty(company, string.format('MasterySetIndex/%s', key), true);
						local monCls = GetClassList('Monster')[troublemaker];
						local formatTable = {
							MasteryName = ClassDataText('Mastery', key, 'Title'),
							TroublemakerName = ClassDataText('ObjectInfo', monCls.Info.name, 'Title'),
						};
						ldm:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('MasterySetAvailableByTroublemaker'), formatTable));
						ldm:AddChat('Notice', FormatMessageText(GuideMessageText('MasterySetAvailableByTroublemakerChat'), formatTable), {});
						return;
					end
				end
			end
		end)();
	end
	dc:Commit('AutoMasterySetIndexUpdate');
end
function CheckTechniqueUnlock(ldm, company, dc)
	for _, tech in pairs(company.Technique) do
		if tech.Opened and tech.Researched then
			for _, unlockTech in ipairs(tech.UnLockTechnique) do
				local curUnlockTechnique = company.Technique[unlockTech];
				if curUnlockTechnique and curUnlockTechnique.name ~= nil then
					if not curUnlockTechnique.Opened then
						dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', curUnlockTechnique.name), true);
						dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', curUnlockTechnique.name), true);
					end
				end
			end
		end
	end
	
	-- 에러 코렉션
	local testTechniques = {};
	if company.MissionCleared.Tutorial_PugoStreet then
		table.insert(testTechniques, 'Consideration');
		table.insert(testTechniques, 'Challenger');
	end
	-- 제작서 언락
	if company.Progress.Tutorial.MachineCraft >= 3 then
		table.append(testTechniques, { 'TrainingManualModule', 'TrainingManualModule2', 'TrainingManualModule3', 'TrainingManualModule4' });
	end
	for _, testTech in ipairs(testTechniques) do
		if not company.Technique[testTech].Opened then
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', testTech), true);
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', testTech), true);
		end
	end
	dc:Commit('CheckTechniqueUnlock');
end
function CheckRecipeUnlock(ldm, company, dc)
	-- 숙련도에 따른 레시피 언락 처리
	for _, recipe in pairs(company.Recipe) do
		if recipe.Opened and recipe.Exp >= recipe.MaxExp then
			for _, unlockRecipeName in ipairs(recipe.UnLockRecipe) do
				local unlockRecipe = GetWithoutError(company.Recipe, unlockRecipeName);
				if unlockRecipe and not unlockRecipe.Opened and unlockRecipe.AutoUnLock then
					UpdateUnlockRecipe(dc, company, unlockRecipeName);
				end
			end
		end
	end
	dc:Commit('CheckRecipeUnlock');
end
function CheckCostumeSystemMail(ldm, company, dc)
	local updateSystemMail = false;
	local systemMailList = GetClassList('SystemMail');
	local rosterList = GetAllRoster(company);
	for _, roster in ipairs(rosterList) do
		local costumeMailName = 'ItemSupply_Costume_'..roster.name;
		local costumeMailCls = systemMailList[costumeMailName];
		if costumeMailCls ~= nil and not company.SystemMailReceived[costumeMailName] then
			dc:GiveSystemMailOneKey(company, costumeMailName, true);
			dc:UpdateCompanyProperty(company, string.format('SystemMailReceived/%s', costumeMailName), true);
			updateSystemMail = true;
		end
	end
	if updateSystemMail then
		dc:Commit('CheckCostumeSystemMail');
	end
end
function CheckBeastActiveAbility(ldm, company, dc)
	local needCommit = false;
	local rosterList = GetAllRoster(company, 'Beast');	
	for _, pcInfo in ipairs(rosterList) do
		local beastType = GetWithoutError(pcInfo, 'BeastType');
		local availableAbilities = {};
		local startAbilities = {};
		for __, abilitySlot in ipairs(beastType.Abilities) do
			if abilitySlot.RequireLv <= pcInfo.JobLv and availableAbilities[abilitySlot.Name] == nil then
				availableAbilities[abilitySlot.Name] = true;
			end
			if abilitySlot.RequireLv <= 1 and StringToBool(abilitySlot.Default) and startAbilities[abilitySlot.Name] == nil then
				startAbilities[abilitySlot.Name] = true;
			end
		end
		
		-- 유효하지 않은 어빌리티 해제
		local activeAbilitySet = table.map(pcInfo.ActiveAbility, function (v) return v; end);
		for abilityName, isActive in pairs(activeAbilitySet) do
			if isActive and not availableAbilities[abilityName] then
				dc:UpdatePCProperty(pcInfo, string.format('ActiveAbility/%s', abilityName), false);
				activeAbilitySet[abilityName] = false;
				needCommit = true;
			end
		end
		
		-- 활성화된 어빌리티가 하나도 없으면 리셋
		local activeAbilityCount = 0;
		for _, isActive in pairs(activeAbilitySet) do
			if isActive then
				activeAbilityCount = activeAbilityCount + 1;
			end
		end
		if activeAbilityCount == 0 then
			for abilityName, _ in pairs(startAbilities) do
				dc:UpdatePCProperty(pcInfo, string.format('ActiveAbility/%s', abilityName), true);
				needCommit = true;
			end
		end
	end
	if needCommit then
		dc:Commit('CheckBeastActiveAbility');
	end
end
function CheckMachineInvalidMastery(ldm, company, dc)
	local needCommit = false;
	
	local checkCategorySet = {};
	local masteryCategoryList = GetClassList('MasteryCategory');
	for _, masteryCategory in pairs(masteryCategoryList) do
		if masteryCategory.EquipSlot ~= 'None' then
			local isMachine = false;
			for _, race in ipairs(masteryCategory.EnableRace) do
				if race.name == 'Machine' then
					isMachine = true;
					break;
				end
			end
			if not isMachine then
				checkCategorySet[masteryCategory.name] = true;
			end
		end
	end
	
	local rosterList = GetAllRoster(company, 'Machine');	
	for _, pcInfo in ipairs(rosterList) do
		for i = 1, pcInfo.MasteryBoard.Count do
			local boardIndex = i - 1;
			local masteryTable = GetMastery(pcInfo, boardIndex);
			for _, mastery in pairs(masteryTable) do
				if checkCategorySet[mastery.Category.name] then
					-- 1) 로스터 마스터리 레벨 초기화
					dc:UpdateMasteryLv(pcInfo, mastery.name, 0, boardIndex);
					-- 2) 회사 마스터리 카운트 증가
					dc:AcquireMastery(company, mastery.name, 1, true);
					needCommit = true;
				end
			end
		end
	end
	if needCommit then
		dc:Commit('CheckMachineInvalidMastery');
	end
end
function CheckTransmogOpened(ldm, company, dc)
	if not company.NeedTransmogOpenedFix then
		return;
	end

	local itemList = GetClassList('Item');

	local opened = {};
	-- 인벤토리
	local allItems = GetAllItems(company);
	for i, item in ipairs(allItems) do
		if item.UnlockTransmog then
			opened[item.name] = true;
		end
	end
	-- 창고
	local allWareItems = GetAllWareItems(company);
	for i, item in ipairs(allWareItems) do
		if item.UnlockTransmog then
			opened[item.name] = true;
		end
	end
	-- 장비
	local rosters = GetAllRoster(company, 'Pc');
	for _, pcInfo in ipairs(rosters) do
		local item = SafeIndex(pcInfo, 'Object', 'Weapon');
		if item and item.UnlockTransmog then
			opened[item.name] = true;
		end
	end
	-- 번들 장비
	local rosters = GetAllRoster(company, 'Pc');
	for _, pcInfo in ipairs(rosters) do
		for key, info in pairs(pcInfo.BundleEquipment) do
			local item = itemList[info.Item];
			if item and item.UnlockTransmog then
				opened[item.name] = true;
			end
		end
	end	
	-- 레시피
	for _, recipe in pairs(company.Recipe) do
		if recipe.Opened then
			local item = itemList[recipe.name];
			if item and item.UnlockTransmog then
				opened[item.name] = true;
			end
		end
	end	
	-- 형상변환 언락
	for key, _ in pairs(opened) do
		if not company.TransmogOpened[key] then
			dc:UpdateCompanyProperty(company, string.format('TransmogOpened/%s', key), true);
		end
	end
	
	dc:UpdateCompanyProperty(company, 'NeedTransmogOpenedFix', false);
	dc:Commit('CheckTransmogOpened');
end
function CheckJointTrainingBotTeamNotified(ldm, company, dc, noMessage)
	-- 합동 훈련 튜토리얼 완료
	if not company.JointTrainingMenu.Opened or company.Progress.Tutorial.JointTraining < 5 then
		return;
	end
	-- 합동 훈련 모드 목록
	local jointTrainingModeList = {};
	for _, cls in pairs (GetClassList('JointTrainingMode')) do
		if not cls.Developing then
			table.insert(jointTrainingModeList, cls);
		end
	end
	table.sort(jointTrainingModeList, function (a, b)
		return a.Order < b.Order;
	end);
	-- 팀 체크
	local needCommit = false;
	local teamSet = {};
	for _, mode in ipairs(jointTrainingModeList) do
		for _, matchingRule in pairs(mode.BotMatchingRule) do
			local availableBotTeams = mode:AvailableBotTeamsByCompany(company, matchingRule.name);
			for _, team in pairs(availableBotTeams) do
				-- 스테이지 진행도가 필요한 팀만 체크
				if (team.RequireStageLv > 0 or team.NeedUnlockTest) and not company.JTBotTeamNotified[team.name] then
					-- 메시지는 모드마다 띄어줌
					if not noMessage then
						ldm:ShowFrontmessageWithText(GameMessageFormText({ Type='JTBotTeamActivated', JTMode=mode.name, JTBotTeam=team.name }, 'Corn'), 'Corn');
					end
					-- 프로퍼티는 팀 당 한번만 처리
					if not teamSet[team.name] then
						dc:UpdateCompanyProperty(company, string.format('JTBotTeamNotified/%s', team.name), true);
						needCommit = true;
						teamSet[team.name] = true;
					end
				end

			end
		end
	end
	if needCommit then
		dc:Commit('CheckJointTrainingBotTeamNotified');
	end
end
function ProgressJTBotTeamNotified(ldm, self, company, env, parsedScript)
	local dc = ldm:GetDatabaseCommiter();
	CheckJointTrainingBotTeamNotified(ldm, company, dc, true);
end

function CheckAsiaServerErrorReward(ldm, company, dc)
	if not company.NeedAsiaServerErrorReward then
		return;
	end

	local maxLv = 0;
	local rosters = GetAllRoster(company, 'Pc');
	for i, pcInfo in ipairs(rosters) do
		maxLv = math.max(maxLv, pcInfo.Lv);
	end
	LogAndPrint('CheckAsiaServerErrorReward - company:', company.CompanyName, ', maxLv:', maxLv);
	if maxLv <= 0 then
		return;
	end	
	
	-- 3레벨 보정
	maxLv = math.min(maxLv + 3, 50);
	
	local allRosters = GetAllRoster(company, 'All');
	for _, pcInfo in ipairs(allRosters) do
		-- 3레벨 증가
		local curLv = pcInfo.Lv;
		local nextLv = math.min(curLv + 3, 50);
		if nextLv > curLv then
			LogAndPrint(string.format(' - %s Lv: %d -> %d', pcInfo.RosterKey, curLv, nextLv));
			dc:UpdatePCProperty(pcInfo, 'Lv', nextLv);
		end
		-- 직업레벨 16렙
		local targetjob = pcInfo.Object.Job.name;
		local targetKey, expKey;
		if pcInfo.RosterType == 'Pc' then
			targetKey = string.format('EnableJobs/%s/Lv', targetjob);
			expKey = string.format('EnableJobs/%s/Exp', targetjob);
		elseif pcInfo.RosterType == 'Beast' or pcInfo.RosterType == 'Machine' then
			targetKey = 'JobLv';
			expKey = 'JobExp';
		end
		local prevJobLv = SafeIndex(pcInfo, unpack(string.split(targetKey, '/')));
		local prevJobExp = SafeIndex(pcInfo, unpack(string.split(expKey, '/')));
		if prevJobLv < 16 then
			LogAndPrint(string.format(' - %s JobLv: %d, %d -> 16, 0', pcInfo.RosterKey, prevJobLv, nextLv));
			dc:UpdatePCProperty(pcInfo, targetKey, 16);
			dc:UpdatePCProperty(pcInfo, expKey, 0);
		end
	end
	
	-- 빌 지급
	local vill = 0;
	if maxLv <= 10 then
		vill = 250000;
	elseif maxLv <= 20 then
		vill = 500000;	
	elseif maxLv <= 30 then
		vill = 1000000;
	elseif maxLv <= 40 then
		vill = 1500000;
	elseif maxLv <= 50 then
		vill = 2000000;
	end
	LogAndPrint(string.format(' - Vill: +%d', vill));
	dc:AddCompanyProperty(company, 'Vill', vill);
	
	-- 훈련서 지급
	local count = 0;
	if maxLv <= 10 then
		count = 1000;
	elseif maxLv <= 20 then
		count = 1000;	
	elseif maxLv <= 30 then
		count = 1000;
	elseif maxLv <= 40 then
		count = 1000;
	elseif maxLv <= 50 then
		count = 1000;
	end
	LogAndPrint(string.format(' - Statement_Mastery: +%d', count));
	dc:GiveItem(company, 'Statement_Mastery', count, true);
	
	-- 아이템 지급
	local itemLv = {};
	if maxLv <= 10 then
		itemLv = {};
	elseif maxLv <= 20 then
		itemLv = { 15, 20 };	
	elseif maxLv <= 30 then
		itemLv = { 25, 30 };
	elseif maxLv <= 40 then
		itemLv = { 35, 40 };
	elseif maxLv <= 50 then
		itemLv = { 45 };
	end
	
	local itemList = GetClassList('Item');
	local itemLvList = {};
	for k, itemCls in pairs(itemList) do
		if (itemCls.Category.name == 'Weapon' or itemCls.Category.name == 'Armor') and itemCls.Rank.name == 'Epic' then
			local lv = itemCls.RequireLv;
			if itemLvList[lv] == nil then
				itemLvList[lv] = {};
			end
			table.insert(itemLvList[lv], itemCls);
		end
	end
	
	for _, pcInfo in ipairs(rosters) do
		for _, lv in ipairs(itemLv) do
			local weapons = table.filter(itemLvList[lv] or {}, function(itemCls)
				for _, enableEquipWeapon in ipairs (pcInfo.Object.EnableEquipWeapon) do
					if itemCls.Type.name == enableEquipWeapon then
						return true;
					end
				end
				return false;
			end);
			local armors = table.filter(itemLvList[lv] or {}, function(itemCls)
				for _, enableEquipBody in ipairs (pcInfo.Object.EnableEquipBody) do
					if itemCls.Type.name == enableEquipBody then
						return true;
					end
				end
				return false;
			end);
			LogAndPrint(pcInfo.name, lv);
			LogAndPrint('- weapons:', table.map(weapons or {}, function(itemCls) return itemCls.name end));
			LogAndPrint('- armors:', table.map(armors or {}, function(itemCls) return itemCls.name end));
			for _, itemCls in ipairs(weapons) do
				dc:GiveItem(company, itemCls.name, 10, true);
			end
			for _, itemCls in ipairs(armors) do
				dc:GiveItem(company, itemCls.name, 10, true);
			end
		end
	end
	
	-- 추가 세트 아이템 제작 재료
	if maxLv >= 41 then
		local rewardList = {};
		local setList = { 'GoldNeguriESPSet', 'GoldNeguriAttackSet' };
		for _, setName in ipairs(setList) do
			local setCls = GetClassList('ItemSet')[setName];
			for i = 1, 5 do
				local itemName = setCls[string.format('Item%d', i)];
				LogAndPrint('i:', i, ', itemName:', itemName);
				local recipeCls = GetClassList('Recipe')[itemName];
				for _, matInfo in pairs(recipeCls.RequireMaterials) do
					rewardList[matInfo.Item] = (rewardList[matInfo.Item] or 0) + 10 * matInfo.Amount;
				end
			end
		end
		LogAndPrint('rewardList:', rewardList);
		for itemName, itemCount in pairs(rewardList) do
			dc:GiveItem(company, itemName, itemCount, true);
		end
	end
		
	dc:UpdateCompanyProperty(company, 'NeedAsiaServerErrorReward', false);
	dc:Commit('CheckAsiaServerErrorReward');
end
function CheckChinaServerErrorReward(ldm, company, dc)
	if not company.NeedChinaServerErrorReward then
		return;
	end

	local maxLv = 0;
	local rosters = GetAllRoster(company, 'Pc');
	for i, pcInfo in ipairs(rosters) do
		maxLv = math.max(maxLv, pcInfo.Lv);
	end
	LogAndPrint('CheckChinaServerErrorReward - company:', company.CompanyName, ', maxLv:', maxLv);
	if maxLv <= 0 then
		return;
	end
	
	-- 빌 지급
	local vill = 0;
	if maxLv <= 10 then
		vill = 0;
	elseif maxLv <= 20 then
		vill = 50000;	
	elseif maxLv <= 30 then
		vill = 100000;
	elseif maxLv <= 40 then
		vill = 150000;
	elseif maxLv <= 50 then
		vill = 200000;
	else
		vill = 250000;
	end
	LogAndPrint(string.format(' - Vill: +%d', vill));
	-- dc:AddCompanyProperty(company, 'Vill', vill);
	
	-- 훈련서 지급
	local count = 0;
	if maxLv <= 10 then
		count = 1000;
	elseif maxLv <= 20 then
		count = 1000;	
	elseif maxLv <= 30 then
		count = 1000;
	elseif maxLv <= 40 then
		count = 1000;
	elseif maxLv <= 50 then
		count = 1000;
	else
		count = 1000;
	end
	LogAndPrint(string.format(' - Statement_Mastery: +%d', count));
	-- dc:GiveItem(company, 'Statement_Mastery', count, true);
	
	local mailKey = 'ItemSupply_TrainingManual_1000';
	dc:GiveSystemMail(company, mailKey, mailKey, mailKey, 'Statement_Mastery', count, { Vill = vill }, nil, 'System');
		
	dc:UpdateCompanyProperty(company, 'NeedChinaServerErrorReward', false);
	dc:Commit('CheckChinaServerErrorReward');
end

-- PC 우호도 보정
function CheckPCFriendshipFix(ldm, company, dc)
	local rosters = GetAllRoster(company, 'Pc');
	-- 최초 시작 시 성격 오픈
	if company.NeedPCPersonalityFix then
		local pcInfoMap = {};
		for _, pcInfo in ipairs(rosters) do
			pcInfoMap[pcInfo.name] = pcInfo;
		end
		-- 성격 보정
		local personalityList = {
			{ Roster = 'Albus', Personality = 'Albus_Sion_FirstColleague', Checker = function(company) return company.Progress.Tutorial.Office >= 31 end },
			{ Roster = 'Albus', Personality = 'Albus_Sion_Debt', RemovePersonality = 'Albus_Sion_FirstColleague', Checker = function(company) return company.Progress.Tutorial.Office >= 44 end },
			{ Roster = 'Albus', Personality = 'Albus_Sion_Memories', RemovePersonality = 'Albus_Sion_Debt', Checker = function(company) return company.Progress.Character.Sion >= 4 end },
			{ Roster = 'Albus', Personality = 'Albus_Irene_HeartBrokenHero', Checker = function(company) return company.Progress.Character.Irene >= 11 end },
			{ Roster = 'Sion', Personality = 'Sion_HeroIrene', Checker = function(company) return company.Progress.Character.Irene >= 9 end },
			{ Roster = 'Sion', Personality = 'Sion_Albus_Memories', Checker = function(company) return company.Progress.Character.Sion >= 4 end },
			{ Roster = 'Irene', Personality = 'Irene_OverexposureHatred', Checker = function(company) return company.Progress.Character.Heissing >= 7 end },
			{ Roster = 'Anne', Personality = 'Anne_GoHomeWithHero', Checker = function(company) return company.Progress.Character.Sion >= 4 end },
			{ Roster = 'Anne', Personality = 'Anne_HelloFox', Checker = function(company) return company.Progress.Tutorial.Office_Night >= 3 end },
		};
		for _, info in ipairs(personalityList) do
			local pcInfo = pcInfoMap[info.Roster];
			if pcInfo and info.Checker(company) then
				if info.RemovePersonality then
					dc:UpdatePCProperty(pcInfo, string.format('Personalities/%s/Opened', info.RemovePersonality), false);
				end
				dc:UpdatePCProperty(pcInfo, string.format('Personalities/%s/Opened', info.Personality), true);
			end
		end
		dc:UpdateCompanyProperty(company, 'NeedPCPersonalityFix', false);
		dc:Commit('NeedPCPersonalityFix');
	end
	
	-- 최초 시작 시 성격 오픈 2
	if company.NeedPCPersonalityFix2 then
		local pcInfoMap = {};
		for _, pcInfo in ipairs(rosters) do
			pcInfoMap[pcInfo.name] = pcInfo;
		end
		-- 성격 보정
		local personalityList = {
			{ Roster = 'Albus', Personality = 'Albus_EmptyPlaceOfMe', Checker = function(company) return company.Progress.Character.Albus >= 3 end },
			{ Roster = 'Sion', Personality = 'Sion_GoodFoodTogether', Checker = function(company) return company.Stats.FoodSetEffectCount >= 1 end },
			{ Roster = 'Ray', Personality = 'Ray_UnvisibleWall', Checker = function(company) return company.Progress.Character.Albus >= 24 end },
			{ Roster = 'Giselle', Personality = 'Giselle_TemporaryTogether', Checker = function(company) return company.MissionCleared.Tutorial_TrainingRoomAfter end },
		};
		for _, info in ipairs(personalityList) do
			local pcInfo = pcInfoMap[info.Roster];
			if pcInfo and info.Checker(company) then
				if info.RemovePersonality then
					dc:UpdatePCProperty(pcInfo, string.format('Personalities/%s/Opened', info.RemovePersonality), false);
				end
				dc:UpdatePCProperty(pcInfo, string.format('Personalities/%s/Opened', info.Personality), true);
			end
		end
		dc:UpdateCompanyProperty(company, 'NeedPCPersonalityFix2', false);
		dc:Commit('NeedPCPersonalityFix2');
	end
	
	-- 최초 시작 시 우호도 보정
	if company.NeedPCFriendshipPointFix then
		-- 우호도 보정
		for i, from in ipairs(rosters) do
			for j, to in ipairs(rosters) do
				-- 카일리는 지젤에 대한 우호도가 기본적으로 증가하지 않으므로, 보정 로직에서도 제외함
				if i ~= j and not (from.name == 'Kylie' and to.name == 'Giselle') then
					local missionClear = to.Stats.MissionClear;
					local addPoint = missionClear * 50 * (10 - from.SlotIndex) / 10;
					UpdatePCFriendshipNoBoundary(dc, from, to, addPoint);
				end
			end
		end
		dc:UpdateCompanyProperty(company, 'NeedPCFriendshipPointFix', false);
		dc:Commit('NeedPCFriendshipPointFix');
	end
end

-- PC 우호도
function UpdateMissionPCFriendship(ldm, company)
	local dc = ldm:GetDatabaseCommiter();

	-- 미션 내 우호도 증감 반영
	local rosters = GetAllRoster(company, 'Pc');
	for i, pc in ipairs(rosters) do
		for objName, addPoint in pairs(pc.MissionFriendshipChange) do
			local target = GetRoster(company, objName);		
			if target and addPoint ~= 0 then
				local newFriendship, newFriendshipPoint, _, prevFriendship = UpdatePCFriendship(dc, pc, target, addPoint, true);
				if newFriendship ~= prevFriendship then
					ldm:ShowLobbyNotification('RosterFriendshipChanged', { Roster = pc.name, Friend = target.name, Friendship = newFriendship });
				end
				dc:UpdatePCProperty(pc, 'MissionFriendshipChange/'..target.name, 0);
			end
		end
	end
	
	-- 우호도 감소 시 유대 관계 감소 or 해제
	UpdateBestFriendAutoGradeDown(dc, company, ldm);
	
	dc:Commit('UpdateMissionPCFriendship');

	-- 유대 특성 누락 시의 재선택 처리
	local rosters = GetAllRoster(company, 'Pc');
	for i, pc in ipairs(rosters) do
		for j = i + 1, #rosters do
			local target = rosters[j];
			if pc and target and IsBestFriend(pc, target.name) then
				local bestFriendSlot = GetBestFriendSlot(pc, target.name);
				local bestFriendGrade = bestFriendSlot.Grade;
				local initialize = true;
				for grade = 1, bestFriendGrade do
					local bfMastery = bestFriendSlot[string.format('Mastery%d', grade)];
					if bfMastery == 'None' then
						_ProgressAddBestFriendMasteryAction(ldm, dc, pc, target, grade, initialize, 'FixBestFriendMastery');
						initialize = false;
					end
				end
			end
		end
	end
end

-- 코스튬 DLC
local g_rosterCostumeCheckerMap = {
	Albus = function(company)
		return StringToBool(company.LobbyMenu.Inventory.Opened, false);
	end,
	Sion = function(company)
		return company.Progress.Tutorial.Office >= 31;
	end,
	Irene = function(company)
		return company.Progress.Character.Irene >= 9;
	end,
	Anne = function(company)
		return company.Progress.Character.Anne >= 5;
	end,
	Heissing = function(company)
		return company.Progress.Character.Heissing >= 7;
	end,
	Ray = function(company)
		return company.Progress.Character.Ray >= 6;
	end,
	Giselle = function(company)
		return company.Progress.Character.Albus >= 9;
	end,
	Kylie = function(company)
		return company.Progress.Character.Albus >= 16;
	end,
	Leton = function(company)
		return company.Progress.Character.Leton >= 9;
	end,
	Alisa = function(company)
		return company.Progress.Character.Albus >= 31;
	end,
	Bianca = function(company)
		return company.Progress.Character.Albus >= 31;
	end,
	Misty = function(company)
		return company.Progress.Character.Albus >= 53;
	end,
};
---@param dc DatabaseCommiter
function CheckDLCCostume(ldm, company, dc)
	local enableRosterSet = {};
	local rosterList = GetAllRoster(company, 'Pc');
	for _, roster in ipairs(rosterList) do
		local checker = g_rosterCostumeCheckerMap[roster.name];
		if checker and checker(company) then
			enableRosterSet[roster.name] = true;
		end
	end

	local itemCounter = LobbyInventoryItemCounter(company);
	---@type fun(itemName:string,equipSlot:string):equip:boolean,roster:roster,equipIndex:integer
	local equipChecker = LobbyEquipItemChecker(company, 'Pc');

	local dlcItemList = {};
	local itemRevoked = false;
	for _, dlcCls in pairs(GetClassList('DLC')) do
		if dlcCls.IsCostume then
			if IsDLCInstalled(company, dlcCls.name) then
				local itemList = {};
				local isEnable = false;
				for _, costumeCls in ipairs(dlcCls.CostumeList) do
					local pcName = SafeIndex(costumeCls, 'PC', 'name');
					if enableRosterSet[pcName] then
						local itemName = costumeCls.Item.name;
						if itemCounter(itemName, true) <= 0 and not equipChecker(itemName, 'Costume') then
							table.insert(itemList, costumeCls.Item);
						end
						isEnable = true;
					end
				end
				local needOpened = false;
				if isEnable and not SafeIndex(company, 'DLC', dlcCls.name, 'Opened') then
					needOpened = true;
				end
				if needOpened or #itemList > 0 then
					table.insert(dlcItemList, { DLC = dlcCls, ItemList = itemList });
				end
			else
				for _, costumeCls in ipairs(dlcCls.CostumeList) do
					local itemName = costumeCls.Item.name;
					local invItem = GetInventoryItemByType(company, itemName);
					if invItem then
						dc:TakeItem(invItem, 1);
						itemRevoked = true;
					end
					local wareItem = GetWarehouseItemByType(company, itemName);
					if wareItem then
						dc:TakeItemWarehouse(wareItem, 1);
						itemRevoked = true;
					end
					local equipped, roster, equipIndex = equipChecker(itemName, 'Costume');
					if equipped then
						dc:UseItem(roster, 'Costume', false, equipIndex);
						itemRevoked = true;
					end
				end
			end
		end
	end
	if #dlcItemList > 0 then
		table.sort(dlcItemList, function(a, b) return a.DLC.Order < b.DLC.Order end);

		-- 메시지, 아이템 지급
		for _, dlcItem in ipairs(dlcItemList) do
			-- DLC용 메시지
			ldm:ShowFrontmessageWithText(GameMessageFormText({ Type = 'CostumeDLCMessage', DLC = dlcItem.DLC.name }, 'Corn'), 'Corn');
			-- Opened 프로퍼티
			dc:UpdateCompanyProperty(company, string.format('DLC/%s/Opened', dlcItem.DLC.name), true);
			-- 아이템 지급
			for _, itemCls in ipairs(dlcItem.ItemList) do
				dc:GiveItem(company, itemCls.name, 1, true, "", {}, false);
			end
		end
	end
	if #dlcItemList > 0 or itemRevoked then
		dc:Commit('CheckDLCCostume');
	end
end
-- 캐릭터 레벨업 제한 상승
local g_dlcLvLimitList = {
	{ DLC = 'WhiteLionAndBlackWitch', LimitType = 'WhiteLionAndBlackWitch', Checker = function(company) return company.Progress.Character.Albus >= 31 end },
}
function CheckCharLvLimitByDLC(ldm, company, dc)
	local needCommit = false;
	local curLvLimit = company.CharLvLimit;
	for _, info in ipairs(g_dlcLvLimitList) do
		if SafeIndex(company, 'DLC', info.DLC, 'Opened') and info.Checker(company) then
			local newLvLimit = SafeIndex(GetClassList('CharLvLimit'), info.LimitType, 'Limit');
			if newLvLimit > curLvLimit then
				dc:UpdateCompanyProperty(company, 'CharLvLimitType', info.LimitType);
				needCommit = true;
				curLvLimit = newLvLimit;
			end
		end
	end
	if needCommit then
		dc:Commit('CheckCharLvLimitByDLC');
	end
end