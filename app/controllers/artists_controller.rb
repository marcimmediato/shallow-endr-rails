class ArtistsController < ApplicationController
  before_action :set_artist, only: [:show, :update, :destroy]

  def search
    mbAdapt = Adapter::MBAdapter.new
    #Searches for an artist in DB
    searchTerm = artist_params[:searchTerm].downcase.gsub(' ', '')
    @artist = Artist.find_by(name: searchTerm)
    if(@artist)
      show
    else
      @artistResults = mbAdapt.getArtists(artist_params[:searchTerm])
      @partialMatches = Artist.all.select{ |artist| artist.name.include?(searchTerm)}
      if (@partialMatches)
        @partialMatchNames = @partialMatches.map {|match| match[:display_name]}
        @artistResults = @artistResults.select {|artist| !@partialMatchNames.include?(artist[:name])}
      end
      @artistResults.map! do |artist|
        mbAdapt.getSpecificArtist(artist[:mbid]) if mbAdapt.getSpecificArtist(artist[:mbid]).date_begin < DateTime.now
      end
      @artistResults.select! { |artist| artist != nil }
      render json: {new_artists: @artistResults, existing_artists: @partialMatches}
    end
  end

  # GET /artists
  def index
    @artists = Artist.all

    render json: @artists
  end

  # GET /artists/1
  def show
    @user = current_user
    @rankings = @user.rankings.find_by(artist_id: @artist.id)
    render json: { artist: @artist, songs: @artist.songs.order('current_weight DESC, name'), rankings: @rankings }
  end

  # POST /artists
  def create
    mbAdapt = Adapter::MBAdapter.new
    @artist = Artist.create(artist_params)
    @artistResults = mbAdapt.getSpecificArtist(artist_params[:mb_id])
    @artistAndAlbums = mbAdapt.getAndAddSongs(@artistResults, @artist)
    render json: @artistAndAlbums
  end

  # PATCH/PUT /artists/1
  def update
    if @artist.update(artist_params)
      render json: @artist
    else
      render json: @artist.errors, status: :unprocessable_entity
    end
  end

  # DELETE /artists/1
  def destroy
    @artist.destroy
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_artist
      @artist = Artist.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def artist_params
      params.require(:artist).permit(:name, :searchTerm, :mb_id, :display_name, :id)
    end
end
