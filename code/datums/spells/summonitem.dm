/obj/effect/proc_holder/spell/summonitem
	name = "Instant Summons"
	desc = "This spell can be used to recall a previously marked item to your hand from anywhere in the universe."
	school = "transmutation"
	base_cooldown = 100
	clothes_req = FALSE
	invocation = "GAR YOK"
	invocation_type = "whisper"
	level_max = 0 //cannot be improved
	cooldown_min = 100

	var/obj/marked_item
	/// List of objects which will result in the spell stopping with the recursion search
	var/static/list/blacklisted_summons = list(/obj/machinery/computer/cryopod = TRUE, /obj/machinery/atmospherics = TRUE, /obj/structure/disposalholder = TRUE, /obj/machinery/disposal = TRUE)
	action_icon_state = "summons"

/obj/effect/proc_holder/spell/summonitem/create_new_targeting()
	return new /datum/spell_targeting/self

/obj/effect/proc_holder/spell/summonitem/cast(list/targets, mob/user = usr)
	for(var/mob/living/target in targets)
		var/list/hand_items = list(target.get_active_hand(),target.get_inactive_hand())
		var/butterfingers = FALSE
		var/message

		if(!marked_item) //linking item to the spell
			message = "<span class='notice'>"
			for(var/obj/item in hand_items)
				if(istype(item, /obj/item/organ/internal/brain)) //Yeah, sadly this doesn't work due to the organ system.
					break
				if(ABSTRACT in item.flags)
					continue
				if(NODROP in item.flags)
					message += "This feels very redundant, but you go through with it anyway.<br>"
				marked_item = 		item
				message += "You mark [item] for recall.</span>"
				name = "Recall [item]"
				break

			if(!marked_item)
				if(hand_items)
					message = "<span class='caution'>You aren't holding anything that can be marked for recall.</span>"
				else
					message = "<span class='notice'>You must hold the desired item in your hands to mark it for recall.</span>"

		else if(marked_item && (marked_item in hand_items)) //unlinking item to the spell
			message = "<span class='notice'>You remove the mark on [marked_item] to use elsewhere.</span>"
			name = "Instant Summons"
			marked_item = 		null

		else if(marked_item && !marked_item.loc) //the item was destroyed at some point
			message = "<span class='warning'>You sense your marked item has been destroyed!</span>"
			name = "Instant Summons"
			marked_item = 		null

		else	//Getting previously marked item
			var/obj/item_to_retrieve = marked_item
			var/infinite_recursion = 0 //I don't want to know how someone could put something inside itself but these are wizards so let's be safe

			while(!isturf(item_to_retrieve.loc) && infinite_recursion < 10) //if it's in something you get the whole thing.
				if(ismob(item_to_retrieve.loc)) //If its on someone, properly drop it
					var/mob/M = item_to_retrieve.loc

					if(issilicon(M) || !M.unEquip(item_to_retrieve)) //Items in silicons warp the whole silicon
						M.visible_message("<span class='warning'>[M] suddenly disappears!</span>", "<span class='danger'>A force suddenly pulls you away!</span>")
						M.forceMove(target.loc)
						M.loc.visible_message("<span class='caution'>[M] suddenly appears!</span>")
						item_to_retrieve = null
						break

					if(ishuman(M)) //Edge case housekeeping
						var/mob/living/carbon/human/C = M
						for(var/X in C.bodyparts)
							var/obj/item/organ/external/part = X
							if(item_to_retrieve in part.embedded_objects)
								part.remove_embedded_object(item_to_retrieve)
								to_chat(C, "<span class='warning'>[item_to_retrieve] that was embedded in your [part] has mysteriously vanished. How fortunate!</span>")
								if(!C.has_embedded_objects())
									C.clear_alert("embeddedobject")
								break

				else
					if(istype(item_to_retrieve.loc,/obj/machinery/atmospherics/portable/)) //Edge cases for moved machinery
						var/obj/machinery/atmospherics/portable/P = item_to_retrieve.loc
						P.disconnect()
						P.update_icon()
					if(is_type_in_typecache(item_to_retrieve.loc, blacklisted_summons))
						break
					item_to_retrieve = item_to_retrieve.loc
					if(istype(item_to_retrieve, /obj/item/storage/backpack/modstorage))
						var/obj/item/storage/backpack/modstorage/bag = item_to_retrieve
						if(bag.source && bag.source.mod)
							item_to_retrieve = bag.source.mod //Grab the modsuit.

				infinite_recursion += 1

			if(!item_to_retrieve)
				return

			if(!isturf(target.loc))
				to_chat(target, "<span class='caution'>You attempt to cast the spell, but it fails! Perhaps you aren't available?</span>")
				return

			item_to_retrieve.loc.visible_message("<span class='warning'>[item_to_retrieve] suddenly disappears!</span>")


			if(target.hand) //left active hand
				if(!target.equip_to_slot_if_possible(item_to_retrieve, slot_l_hand, FALSE, TRUE))
					if(!target.equip_to_slot_if_possible(item_to_retrieve, slot_r_hand, FALSE, TRUE))
						butterfingers = TRUE
			else			//right active hand
				if(!target.equip_to_slot_if_possible(item_to_retrieve, slot_r_hand, FALSE, TRUE))
					if(!target.equip_to_slot_if_possible(item_to_retrieve, slot_l_hand, FALSE, TRUE))
						butterfingers = TRUE
			if(butterfingers)
				item_to_retrieve.loc = target.loc
				item_to_retrieve.loc.visible_message("<span class='caution'>[item_to_retrieve] suddenly appears!</span>")
				playsound(get_turf(target),'sound/magic/summonitems_generic.ogg', 50, 1)
			else
				item_to_retrieve.loc.visible_message("<span class='caution'>[item_to_retrieve] suddenly appears in [target]'s hand!</span>")
				playsound(get_turf(target),'sound/magic/summonitems_generic.ogg', 50, 1)

		if(message)
			to_chat(target, message)
