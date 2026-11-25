#include "utils.h"
#include "application.h"
#include <SDL3/SDL.h>
#include <fstream>
#include <sstream>

void Application::showError(const std::string& errorMessage) const
{
	SDL_ShowSimpleMessageBox(
		SDL_MESSAGEBOX_ERROR,
		"Error",
		errorMessage.c_str(),
		window
	);
}

std::string readTextFile(const std::string &filePath)
{
	std::ifstream infile(filePath);
	if (infile.is_open())
	{
		std::stringstream buffer;
		buffer << infile.rdbuf();
		const std::string output = buffer.str();
		infile.close();
		return output;
	}
	return std::string();
}
