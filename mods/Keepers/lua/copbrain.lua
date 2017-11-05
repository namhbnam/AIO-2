local key = ModPath .. '	' .. RequiredScript
if _G[key] then return else _G[key] = true end

local kpr_original_copbrain_isavailableforassignment = CopBrain.is_available_for_assignment
function CopBrain:is_available_for_assignment(objective)
	if self._unit:base().kpr_is_keeper then
		return
	end

	return kpr_original_copbrain_isavailableforassignment(self, objective)
end

local kpr_original_copbrain_setobjective = CopBrain.set_objective
function CopBrain:set_objective(new_objective, params)
	if new_objective and (new_objective.type == 'follow' or new_objective.type == 'stop' or new_objective.type == 'defend_area') then
		if self._unit:base().kpr_is_keeper then
			local old_objective = self._logic_data.objective
			self._logic_data.objective = Keepers:GetStayObjective(self._unit)
			CopLogicBase.on_new_objective(self._logic_data, old_objective)
			if Keepers:CanChangeState(self._unit) then
				self:set_logic('travel')
				if self._logic_data.is_converted then
					self._unit:movement():action_request({
						type = 'idle',
						body_part = 1,
						sync = true
					})
				end
			end
			return
		end
	end

	kpr_original_copbrain_setobjective(self, new_objective, params)
end

local kpr_original_copbrain_converttocriminal = CopBrain.convert_to_criminal
function CopBrain:convert_to_criminal(mastermind_criminal)
	kpr_original_copbrain_converttocriminal(self, mastermind_criminal)

	local ct = deep_clone(self._logic_data.char_tweak)
	ct.access = 'teamAI1'
	ct.crouch_move = false
	if Keepers.settings.jokers_run_like_teamais then
		ct.kpr_tweak_table = 'russian'
		ct.move_speed = tweak_data.character.russian.move_speed
	end
	self._logic_data.important = true
	self._logic_data.char_tweak = ct
	self._unit:movement():tweak_data_clbk_reload(ct)

	self._unit:base().kpr_minion_owner_peer_id = alive(mastermind_criminal) and managers.network:session():peer_by_unit(mastermind_criminal):id() or 1
end

local kpr_original_copbrain_setimportant = CopBrain.set_important
function CopBrain:set_important(state)
	if self._logic_data.is_converted then
		state = true
	end
	kpr_original_copbrain_setimportant(self, state)
end
