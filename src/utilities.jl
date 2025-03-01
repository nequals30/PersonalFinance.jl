export prompt_yesno

function prompt_yesno(prompt::String = "Do you want to continue?", failMessage::String = "Operation aborted by user.")
	while true
		print("> > > " * prompt * " [y/n]: ")
		input = readline()
        input = lowercase(strip(input))
        if input == "y" || input == "yes"
            return true
        elseif input == "n" || input == "no"
			printstyled("ERROR: $(failMessage)\n", bold=true, color=:red)
			return false
        else
            println("Invalid input. Please enter 'y' for yes or 'n' for no.\n")
        end
	end

end
