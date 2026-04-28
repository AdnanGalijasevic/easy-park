FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj files and restore to leverage Docker layer caching
COPY ["EasyPark.API/EasyPark.API.csproj", "EasyPark.API/"]
COPY ["EasyPark.Model/EasyPark.Model.csproj", "EasyPark.Model/"]
COPY ["EasyPark.Services/EasyPark.Services.csproj", "EasyPark.Services/"]
RUN dotnet restore "EasyPark.API/EasyPark.API.csproj"

# Copy the rest of the source code
COPY . .
WORKDIR "/src/EasyPark.API"
RUN dotnet build "EasyPark.API.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "EasyPark.API.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "EasyPark.API.dll"]

