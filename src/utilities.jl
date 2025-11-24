using Dates

export prompt_yesno, excel2date, date2excel

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

 function prompt_input(prompt::String,default::String)
 	println("> > > " * prompt * " (press ENTER for default: $default): ")
 	input = readline()
	println()
	return isempty(input) ? default : input
 end

function excel2date(excelNumber::Number)
	return Date(1899, 12, 30) + Day(excelNumber)
end

function date2excel(date::Date)
	return Dates.value(date - Date(1899,12,30))
end
