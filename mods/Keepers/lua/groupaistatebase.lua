local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local kpr_original_groupaistatebase_clbkminiondies = GroupAIStateBase.clbk_minion_dies
function GroupAIStateBase:clbk_minion_dies(player_key, minion_unit, damage_info)
	if minion_unit:unit_data().name_label_id then
		Keepers:DestroyLabel(minion_unit)		
	end

	kpr_original_groupaistatebase_clbkminiondies(self, player_key, minion_unit, damage_info)
end

local kpr_original_groupaistatebase_clbkminiondestroyed = GroupAIStateBase.clbk_minion_destroyed
function GroupAIStateBase:clbk_minion_destroyed(player_key, minion_unit)
	if minion_unit:unit_data().name_label_id then
		Keepers:DestroyLabel(minion_unit)		
	end

	kpr_original_groupaistatebase_clbkminiondestroyed(self, player_key, minion_unit)
end

local kpr_original_groupaistatebase_converthostagetocriminal = GroupAIStateBase.convert_hostage_to_criminal
function GroupAIStateBase:convert_hostage_to_criminal(unit, peer_unit)
	local player_unit = peer_unit or managers.player:player_unit()
	local unit_data = self._police[unit:key()]
	if unit_data and alive(player_unit) then
		unit:base().kpr_minion_owner_peer_id = player_unit:network() and player_unit:network():peer() and player_unit:network():peer():id()
	end

	kpr_original_groupaistatebase_converthostagetocriminal(self, unit, peer_unit)

	if unit_data then
		Keepers:SetJokerLabel(unit)
	end
end

local kpr_original_groupaistatebase_determineobjectiveforcriminalai = GroupAIStateBase._determine_objective_for_criminal_AI
function GroupAIStateBase:_determine_objective_for_criminal_AI(unit)
	if unit:base().kpr_is_keeper then
		return Keepers:GetStayObjective(unit)
	end

	local owner_id = unit:base().kpr_minion_owner_peer_id
	if owner_id then
		local peer_unit = managers.network:session():peer(owner_id):unit()
		if peer_unit then
			return {
				type = "follow",
				follow_unit = peer_unit,
				scan = true,
				nav_seg = peer_unit:movement():nav_tracker():nav_segment(),
				called = true,
				pos = peer_unit:movement():nav_tracker():field_position(),
			}
		end
	end

	local new_objective = kpr_original_groupaistatebase_determineobjectiveforcriminalai(self, unit)

	if new_objective and new_objective.follow_unit and not unit:base().kpr_following_peer_id then
		local peer = managers.network:session():peer_by_unit(new_objective.follow_unit)
		if peer then
			Keepers:SendState(unit, Keepers:GetLuaNetworkingText(peer:id(), unit, 1), false)
		end
	end

	return new_objective
end

local kpr_original_groupaistatebase_oncriminalneutralized = GroupAIStateBase.on_criminal_neutralized
function GroupAIStateBase:on_criminal_neutralized(unit)
	kpr_original_groupaistatebase_oncriminalneutralized(self, unit)

	if Network:is_server() then
		local must_awake_bots = true
		for _, record in pairs(self._criminals) do
			if not record.ai and record.status ~= "dead" then
				must_awake_bots = false
			end
		end

		if must_awake_bots then
			for _, record in pairs(self._ai_criminals) do
				if record.status ~= "dead" and alive(record.unit) and record.unit:base().kpr_is_keeper then
					Keepers:SendState(record.unit, Keepers:GetLuaNetworkingText(record.unit:base().kpr_following_peer_id or 1, record.unit, 1), false)
				end
			end

			for key, unit in pairs(self._converted_police or {}) do
				if alive(unit) and unit:character_damage() and unit:character_damage().dead and not unit:character_damage():dead() and unit:base().kpr_is_keeper then
					Keepers:SendState(unit, Keepers:GetLuaNetworkingText(unit:base().kpr_minion_owner_peer_id, unit, 1), false)
				end
			end
		end
	end
end

function GroupAIStateBase:upd_team_AI_distance()
	-- yeah, sure
end

function GroupAIStateBase:force_attention_data(unit)
	local force_attention_data = self._force_attention_data
	if not force_attention_data or not alive(unit) then
		return nil
	end
	local u_key = unit:key()
	if self._converted_police[u_key] then
		return nil
	end
	if not alive(force_attention_data.unit) then
		self._force_attention_data = nil
		return nil
	end
	if force_attention_data.include_all_force_spawns and not unit:brain()._logic_data.group and not force_attention_data.excluded_units[u_key] or force_attention_data.included_units[u_key] then
		return force_attention_data
	end
end

local kpr_original_groupaistatebase_removeminion = GroupAIStateBase.remove_minion
function GroupAIStateBase:remove_minion(minion_key, player_key)
	local minion_unit = self._converted_police[minion_key]
	if not minion_unit then
		return
	end

	if not player_key then
		for u_key, u_data in pairs(self._player_criminals) do
			if u_data.minions and u_data.minions[minion_key] then
				player_key = u_key
				break
			end
		end
	end

	if not player_key then
		local owner_id = minion_unit:base().kpr_minion_owner_peer_id
		if not owner_id then
			return
		end
		local peer = managers.network:session():peer(owner_id)
		if not peer then
			return
		end
		local peer_unit = peer:unit()
		if not alive(peer_unit) then
			return
		end
		player_key = peer_unit:key()
		local owner_data = self._player_criminals[player_key]
		if not owner_data.minions then
			owner_data.minions = {}
		end
		owner_data.minions[minion_key] = {}
	end

	if player_key then
		kpr_original_groupaistatebase_removeminion(self, minion_key, player_key)
	end
end
